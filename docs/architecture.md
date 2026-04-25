# COR24 Smalltalk v0 — Architecture

## 1. System Layers

```
+---------------------------------------------+
|  Layer 4: Smalltalk Image                   |
|  Class table, method dictionaries,          |
|  bytecodes, symbols. Lives in the BASIC     |
|  PEEK/POKE scratch heap (addresses 0..767). |
+---------------------------------------------+
|  Layer 3: Tinytalk VM                       |
|  BASIC subroutines: heap helpers, dispatch  |
|  loop, message send, primitives. State      |
|  lives in BASIC variables A..Z and the      |
|  scratch heap.                              |
+---------------------------------------------+
|  Layer 2: COR24 BASIC v1                    |
|  Tokenized line storage, statement          |
|  dispatch, expression evaluator, PEEK/POKE  |
|  scratch RAM (1024 24-bit words).           |
+---------------------------------------------+
|  Layer 1: P-code VM                         |
|  Stack machine; runs the BASIC interpreter  |
|  (a Pascal program compiled to p-code).     |
+---------------------------------------------+
|  Layer 0: COR24 hardware / emulator         |
+---------------------------------------------+
```

The deliverable in this repo is **Layer 4 + Layer 3 only**, both
expressed as BASIC source files. Layers 0..2 are sibling projects
and are treated as a fixed substrate.

The Smalltalk VM is itself an interpreter, so the runtime stack
looks like this at execution time:

```
COR24 hardware
  -> p-code VM (executing pvm.s)
    -> BASIC interpreter (Pascal->p-code)
      -> Smalltalk VM dispatch loop (BASIC code, GOSUB-driven)
        -> a single Smalltalk method (bytecodes in the heap)
```

Three nested fetch/decode/execute loops. That is intentional: the
project is about making the model visible, not fast.

## 2. How Tinytalk Maps onto BASIC

The Tinytalk VM uses *only* what BASIC v1 provides:

| Tinytalk needs                | BASIC v1 mechanism                      |
|-------------------------------|-----------------------------------------|
| Heap (objects, methods, dict) | `PEEK`/`POKE` against scratch addr 0..1023 |
| VM registers (PC, SP, ...)    | Variables `A..Z`                        |
| Stacks (eval, call)           | Heap regions, indexed via PEEK/POKE     |
| Dispatch (bytecode -> action) | Chain of `IF OP=n THEN GOSUB k`         |
| Subroutines                   | `GOSUB`/`RETURN` + global vars          |
| Console I/O                   | `PRINT`, `INPUT`                        |
| Flow control                  | `IF...THEN GOTO`, `FOR/NEXT`            |
| Halt / error                  | `STOP` / `END`                          |

The Smalltalk eval stack and the Smalltalk method-call stack are
*not* the BASIC GOSUB stack — they live in scratch RAM and are
managed by VM register variables.

## 3. Memory Layout

Within BASIC v1's 1024-word PEEK/POKE region (`um[0..1023]`):

```
Addr    Size    Region                  Notes
-----   ----    --------------------    ----------------------
0       512     Object heap             bump-allocated, never freed in v0
512     128     Method bytecode pool    one entry per method body
640     64      Method dictionary       parallel arrays MSEL/MCLS/MBC/MLEN
704     32      Symbol table            selector id -> (no string in v0)
736     32      Class table             0..15 reserved built-ins
768     128     Eval stack              Smalltalk operand stack
896     96      Frame stack             receiver/PC/method/temps per call
992     16      VM scratch / temps      transient
1008    16      Reserved
```

Sizes are tunable; the choice above is sized for the three demos.

The 26 BASIC variables are used as VM registers:

```
P  program counter (byte index into method bytecode)
M  current method (heap pointer)
B  bytecode-pool base for current method
L  current method byte length
R  receiver (object reference, possibly tagged)
C  class of receiver (class table index)
S  eval stack pointer (heap addr)
F  frame stack pointer (heap addr)
T  scratch / temp 0
U  scratch / temp 1
V  scratch / value (last computation)
O  current opcode
A  argument 0 of current send
N  argc / count
I,J,K  loop indices
G  selector id of current send
H  heap allocator pointer (bump)
D  dispatch return slot
E  error code
Q  primitive result
W  used by primitives as scratch
X,Y,Z reserved
```

Because BASIC variables persist across `RUN`, the user can `PRINT
P,M,R,S,V` from the REPL after a STOP to inspect the VM mid-step.

## 4. Object Reference Encoding

Every object reference is a single 24-bit BASIC integer:

```
bit 0 = 1   SmallInteger.  value = ref / 2     (Pascal-style integer div)
bit 0 = 0   Heap pointer.  addr  = ref / 2     (same shift, but the
                                                 low bit was already 0)
```

So for a SmallInteger N, the encoded ref is `2*N + 1`.
For a heap object at scratch address P, the encoded ref is `2*P`.

Helpers (BASIC subroutines):

```
1000 REM ISINT(V) -> R: V AND 1 != 0    ; v1 has logical AND only,
                                          so this is implemented as
                                          R = V - (V/2)*2
1100 REM TOINT(V) -> R: R = (V-1)/2
1200 REM MKINT(N) -> R: R = N*2 + 1
1300 REM ISPTR(V) -> R: complement of ISINT
1400 REM PADDR(V) -> R: R = V/2
```

(See `docs/design.md` § 4 for full details.)

## 5. Dispatch Loop (sketch)

The bytecode interpreter is a long `IF`-chain in BASIC. Each
opcode handler is a separate `GOSUB`. Pseudocode:

```
2000 REM --- FETCH/DECODE/EXECUTE LOOP ---
2010 IF P >= L THEN GOTO 2900   : REM out of bytes, return
2020 O = PEEK(B+P) : P = P + 1
2030 IF O =  0 THEN GOTO 2900           : REM HALT
2040 IF O =  1 THEN GOSUB 3000 : GOTO 2010 : REM PUSH_SELF
2050 IF O =  2 THEN GOSUB 3100 : GOTO 2010 : REM PUSH_LIT
2060 IF O =  7 THEN GOSUB 3700 : GOTO 2010 : REM SEND
2070 IF O =  8 THEN GOSUB 3800 : GOTO 2010 : REM RETURN_TOP
2080 IF O = 13 THEN GOSUB 4300 : GOTO 2010 : REM PRIMITIVE
2090 PRINT "BAD OP " ; O : STOP
2900 RETURN
```

The full opcode set lives in `docs/design.md` § 5.

`SEND` itself is the centerpiece of the system: it pops `argc`
arguments and a receiver, looks up the receiver's class, walks the
method dictionary searching for the selector id, builds a frame on
the frame stack, and re-enters the dispatch loop with `P/B/L/M/R`
re-pointed at the called method's bytecode. (Concrete BASIC pseudocode
in `docs/design.md` § 7.)

## 6. Method Dictionary Layout

Parallel arrays in scratch addressed at base 640:

```
addr 640+i*4 + 0  = class index   (or -1 for unused entry)
addr 640+i*4 + 1  = selector id
addr 640+i*4 + 2  = bytecode start (offset into 512..639)
addr 640+i*4 + 3  = bytecode length
```

Linear scan: walk i = 0..15 looking for matching (class, selector).
If not found in receiver's class, walk superclass (one level in v0
for built-ins; not used by demos).

## 7. Module Breakdown (BASIC files)

The BASIC v1 dialect has no module/include facility, so a "module"
is a numeric range of line numbers in a single `.bas` source file.

| Range       | Module                  | Purpose                               |
|-------------|-------------------------|---------------------------------------|
| 1..99       | image_load              | POKE the prebuilt image into scratch  |
| 100..199    | demo_main               | Top-level demo driver                 |
| 1000..1499  | obj_helpers             | tag/untag, class-of, alloc            |
| 1500..1999  | stack_helpers           | push/pop on eval and frame stacks     |
| 2000..2499  | dispatch_loop           | fetch/decode/execute                  |
| 3000..3999  | opcode_handlers         | one GOSUB per bytecode                |
| 4000..4499  | send_lookup             | message lookup + activate             |
| 4500..4999  | primitives              | built-in primitive routines           |
| 5000..5499  | mini_repl               | tiny parser for the demo grammar      |

A second `.bas` file per demo (`d1_add.bas`, `d2_counter.bas`,
`d3_boolean.bas`) supplies a different `image_load` block but
shares the rest by text concatenation at build time.

## 8. Build / Run Pipeline

```
demo.bas
  cat image_<demo>.bas vm.bas
    -> demo_<demo>.bas
      -> ../sw-cor24-basic/scripts/run-basic.sh demo_<demo>.bas
        -> pv24t (p-code interpreter)
          -> output to stdout
```

The "build" step is text concatenation; there is no compiler here.
A small `scripts/build.sh` will assemble each demo's BASIC source
from `vm.bas` plus the per-demo image header.

## 9. Relationship to the Visual / Tile Composer (Future)

The visual tile composer described in `docs/research.txt` would
emit the *same* bytecode this VM consumes. The architecture leaves
that door open by:

- Making the bytecode set tiny and fully documented (`design.md` § 5).
- Storing the image as a flat sequence of 24-bit words, which a
  future tool can generate without going through BASIC source.
- Defining selectors as small integer ids, decoupling them from
  text. A visual tool can draw the keyword name without the VM
  caring how it was rendered.

That tool is *not* part of v0; this section just records the design
choices that keep it cheap to add later.
