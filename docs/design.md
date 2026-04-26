# COR24 Smalltalk v0 — Design Document

This is the concrete design of the Tinytalk VM hosted on COR24
BASIC v1. Every datum is a BASIC integer; every routine is a BASIC
`GOSUB` block.

## 1. Constraints from the Host

These BASIC v1 facts shape every design choice. (See § 11 for a
fuller list of shortcomings and feature requests.)

1. **No arrays in user programs.** Substitute: `PEEK`/`POKE`
   against the 1024-word scratch RAM at addresses `0..1023`. (For
   addresses below 1024, `PEEK`/`POKE` actually store full 24-bit
   integers, *not* bytes — see `../sw-cor24-basic/src/basic.pas`
   line 120 and 298.)
2. **26 scalar variables.** A..Z. We use them as VM registers.
3. **No `MOD`, no bit ops**, no `XOR`, no `SHL`/`SHR`. Tag-bit
   tricks must use multiplication and integer division.
4. **No `DATA`/`READ`.** The image is loaded by a long sequence
   of `POKE addr,val` lines.
5. **No subroutine parameters.** `GOSUB` has no formal arguments.
   We pass arguments through agreed register variables and document
   the convention at every call site.
6. **No multi-statement lines.** Every BASIC line does one thing.
   This bloats line counts but makes single-stepping obvious.
7. **`STOP` is fatal in v1** (no `CONT`). For interactive
   inspection we instead `END` after `PRINT`-ing key registers.
8. **Tokenized program area: 16 384 bytes.** The full demo —
   image loader + VM — has to fit in there.

## 2. Object Reference Encoding

A reference is a 24-bit BASIC integer, low-bit tagged.

```
ref bit 0 = 1  -> SmallInteger.   value  =  (ref - 1) / 2
ref bit 0 = 0  -> heap pointer.   addr   =   ref      / 2
```

`ref = 0` is reserved as `nil` (an alias for the heap object at
address 0, which the image installs as the canonical nil). `ref =
1` is `0`-as-SmallInteger and is a normal integer, not nil.

### 2.1 Helpers

BASIC has logical (`AND`/`OR`) but *not* bitwise operators, so we
extract the tag with arithmetic:

```basic
1000 REM --- ISINT: input V, output T (1 if SmallInt, 0 if pointer) ---
1010 T = V - (V/2)*2
1020 RETURN

1100 REM --- TOINT: input V (must be SmallInt), output T = decoded int ---
1110 T = (V-1)/2
1120 RETURN

1200 REM --- MKINT: input V = raw int, output T = tagged ref ---
1210 T = V*2 + 1
1220 RETURN

1300 REM --- PADDR: input V (must be heap ref), output T = heap address ---
1310 T = V/2
1320 RETURN
```

(BASIC v1 integer divide truncates toward zero, which is what we
want for non-negative refs. Negative SmallInts are not used by v0
demos but the tagging is symmetric: `-3` encodes as `-5`.)

## 3. Heap Layout

Bump allocator into scratch words `0..511`. Allocation pointer
lives in BASIC variable `H`, initialised to 16 (we leave addresses
0..15 for canonical singletons: nil, true, false).

Every heap object has a 3-word header, then `size` data words:

```
addr+0  class index   (small integer 0..15 for v0)
addr+1  size          (number of data words after header)
addr+2  format        (0 = pointer slots, 1 = bytecode bytes)
addr+3..addr+3+size-1 data words
```

### 3.1 Canonical singletons (installed by image_load)

```
addr 0  : nil           class = UndefinedObject (5), size 0
addr 4  : true          class = True            (3), size 0
addr 8  : false         class = False           (4), size 0
addr 12 : the empty Array (placeholder)
```

### 3.2 Allocator

```basic
4500 REM --- ALLOC: input C=class, N=size, output T=heap ref ---
4510 IF H + 3 + N > 512 THEN E = 4 : RETURN
4520 POKE H, C
4530 POKE H+1, N
4540 POKE H+2, 0
4550 T = H * 2 : REM tagged heap ref
4560 H = H + 3 + N
4570 RETURN
```

`E = 4` is "out of memory" (matches BASIC v1 error code 4).

## 4. Class Table

16 entries at scratch addresses `736..751`, one word each, holding
the *heap address* of the class object for that index:

```
class id  name              superclass id (in v0)
--------  ----------------  ----------------------
   0      Object             - (root)
   1      Class              0
   2      SmallInteger       0
   3      True               0
   4      False              0
   5      UndefinedObject    0
   6      Array              0
   7      Symbol             0
   8      Method             0
   9      Block              0
  10..15  user-defined (Counter goes at 10 for D2)
```

Class object layout (size 3, format 0):

```
data[0]  superclass id
data[1]  instance variable count
data[2]  method-dictionary base index  (always parallel: see § 6)
```

`CLASSOF(ref)` is implemented as:

```basic
4600 REM --- CLASSOF: input V, output T = class id ---
4610 GOSUB 1000 : REM ISINT
4620 IF T = 1 THEN T = 2 : RETURN  : REM SmallInteger
4630 GOSUB 1300 : REM PADDR -> T = heap addr
4640 T = PEEK(T) : RETURN          : REM header word 0
```

## 5. Bytecode Set

14 opcodes. Multi-byte opcodes have an inline operand byte.

| Op | Mnemonic       | Operand | Stack effect           | Notes                        |
|----|----------------|---------|------------------------|------------------------------|
|  0 | HALT           | -       | -                      | terminate dispatch loop      |
|  1 | PUSH_SELF      | -       | (-- self)              | push receiver                |
|  2 | PUSH_LIT n     | byte    | (-- lit_n)             | from method literal table    |
|  3 | PUSH_TEMP n    | byte    | (-- temp_n)            | local in current frame       |
|  4 | STORE_TEMP n   | byte    | (v --)                 | pop into temp                |
|  5 | PUSH_FIELD n   | byte    | (-- field)             | instance var of self         |
|  6 | STORE_FIELD n  | byte    | (v --)                 | write instance var of self   |
|  7 | SEND s,a       | 2 bytes | (rcv a0..a(a-1) -- r)  | s = selector id, a = argc    |
|  8 | RETURN_TOP     | -       | (v -- ) -> caller's v  | unwind one frame             |
|  9 | POP            | -       | (v --)                 |                              |
| 10 | JUMP off       | byte    | -                      | signed offset within method  |
| 11 | JUMP_IF_FALSE  | byte    | (v --)                 | jumps if v == false-object   |
| 12 | PUSH_INT n     | byte    | (-- (int n))           | -128..127 small literal      |
| 13 | PRIMITIVE n    | byte    | -                      | invoke primitive #n          |

Multi-byte operands are signed 8-bit (offsets) or unsigned 8-bit
(indices). Methods longer than 256 bytes are not supported in v0.

### 5.1 Example: `Counter>>incr`

Source (notional): `incr  value := value + 1`

Bytecodes (10 bytes):

```
05 00       PUSH_FIELD 0      ; value
0C 01       PUSH_INT 1
07 01 01    SEND  '+', 1
06 00       STORE_FIELD 0     ; value :=
01          PUSH_SELF
08          RETURN_TOP
```

(Selector ids: `+` = 1. See § 8.)

## 6. Method Dictionary

Parallel pseudo-arrays at scratch addresses 640..703 (16 entries
of 4 words each):

```
640 + i*4 + 0  : class id   (-1 = empty slot)
640 + i*4 + 1  : selector id
640 + i*4 + 2  : bytecode pool offset (byte index within 512..639)
640 + i*4 + 3  : bytecode length
```

The bytecode pool is at scratch addresses 512..639 — *128 words*
holding *up to 128 bytecode bytes* if we use one byte per word,
which we do for v0 simplicity. (A denser packing is possible but
makes the dispatch loop harder to read.)

### 6.1 Lookup

```basic
4000 REM --- LOOKUP: input C=class, G=selector, output T=index or -1 ---
4010 I = 0
4020 IF I >= 16 THEN T = -1 : RETURN
4030 IF PEEK(640 + I*4) = C THEN GOTO 4060
4040 I = I + 1 : GOTO 4020
4060 IF PEEK(640 + I*4 + 1) = G THEN T = I : RETURN
4070 I = I + 1 : GOTO 4020
```

Superclass walking is omitted in v0 because all built-in methods
live on the receiver's own class (SmallInteger, True, False,
Counter). When user-defined classes need inheritance, replace
4030 with a class-chain walk.

## 7. Send / Activation

Frame layout on the frame stack (1 frame = 6 words):

```
0  saved P  (caller program counter, byte index)
1  saved B  (caller bytecode pool base)
2  saved L  (caller method byte length)
3  saved M  (caller method ref)
4  saved R  (caller receiver)
5  temp base index (start of this frame's temps in the eval stack)
```

`SEND` pseudocode:

```basic
3700 REM --- SEND ---
3710 G = PEEK(B + P) : P = P + 1     : REM selector id
3720 N = PEEK(B + P) : P = P + 1     : REM argc
3730 REM stack: ... rcv a0 ... a(N-1)  with SP pointing past the top
3740 R = PEEK(768 + S - 1 - N)       : REM receiver under args
3750 V = R : GOSUB 4600              : REM CLASSOF -> T
3760 C = T
3770 GOSUB 4000                      : REM LOOKUP -> T (entry idx)
3780 IF T < 0 THEN GOSUB 4900 : RETURN  : REM doesNotUnderstand:
3790 REM push frame, then re-point P/B/L/M to the called method
3800 REM (full frame push elided here; see vm.bas)
3810 RETURN
```

Primitive methods short-circuit the activation: their bytecode is
just `13 nn 08` (PRIMITIVE n; RETURN_TOP). The PRIMITIVE handler
does the work in BASIC and pushes the result; RETURN_TOP unwinds.

## 8. Selector Table

Selector ids are small integers. v0 reserves these:

| id | text       | arity |
|----|------------|-------|
|  1 | `+`        | 1     |
|  2 | `-`        | 1     |
|  3 | `*`        | 1     |
|  4 | `<`        | 1     |
|  5 | `print`    | 0     |
|  6 | `init`     | 0     |
|  7 | `incr`     | 0     |
|  8 | `value`    | 0     |
|  9 | `ifTrue:ifFalse:` | 2 |
| 10 | `at:`      | 1     |
| 11 | `at:put:`  | 2     |
| 12 | `=`        | 1     |
| 13 | `new`      | 0     |

The mini REPL (§ 10) maps the textual form to the id at parse
time. There is no Symbol *string* in v0 — only the id.

## 9. Primitives

Primitive handlers are at line 4500 onward, dispatched by `O`
(opcode 13's operand was just read into `O`):

```basic
4300 REM --- PRIMITIVE n ---
4310 O = PEEK(B + P) : P = P + 1
4320 IF O = 1 THEN GOSUB 4500 : RETURN  : REM SmallInt +
4330 IF O = 2 THEN GOSUB 4520 : RETURN  : REM SmallInt -
4340 IF O = 3 THEN GOSUB 4540 : RETURN  : REM SmallInt *
4350 IF O = 4 THEN GOSUB 4560 : RETURN  : REM SmallInt <
4360 IF O = 5 THEN GOSUB 4580 : RETURN  : REM print
4370 IF O = 6 THEN GOSUB 4600 : RETURN  : REM new instance
4380 PRINT "BAD PRIM ";O : E = 1 : RETURN
```

### 9.1 SmallInt + (primitive 1)

```basic
4500 REM --- prim 1: SmallInt + ---
4510 GOSUB 1500 : REM POP -> A (right operand)
4520 GOSUB 1500 : REM POP -> R (left operand, the receiver)
4530 GOSUB 1100 : V=A : T=0     : REM TOINT(A)
4540 W = T
4550 V = R : GOSUB 1100         : REM TOINT(R)
4560 V = T + W                  : REM raw sum
4570 GOSUB 1200                 : REM MKINT -> T
4580 V = T : GOSUB 1400         : REM PUSH
4590 RETURN
```

(BASIC pseudocode — production code lives in `vm.bas`.)

### 9.2 print (primitive 5)

```basic
4580 REM --- prim 5: print top-of-stack as decimal SmallInt ---
4590 GOSUB 1500 : REM POP -> R
4600 V = R : GOSUB 1100 : REM TOINT
4610 PRINT T
4620 V = R : GOSUB 1400 : REM push receiver back as result
4630 RETURN
```

## 10. Mini Source REPL (Optional)

A tiny non-general parser handles three input shapes for the demos:

| Input shape                    | Bytecode produced                         |
|--------------------------------|-------------------------------------------|
| `<int> + <int>`                | PUSH_INT a; PUSH_INT b; SEND '+',1; HALT  |
| `c init`, `c incr`, `c value`  | PUSH_FIELD 0 of `c`; SEND ...,0; HALT     |
| `<int> < <int> ifTrue:ifFalse:`| (precompiled D3 method body)              |

The parser reads from the BASIC `INPUT` line buffer. It matches
exact keywords; anything else is an error. v0 does *not* implement
a general Smalltalk reader.

For demos D2 and D3, the "image_load" block writes a fully-formed
method into the bytecode pool, and the demo driver only needs to
issue the right `SEND`.

## 11. Host (BASIC v1) Shortcomings & Feature Requests

These are the BASIC v1 limitations that hurt this design. They are
ranked by how much they hurt v0 specifically.

### 11.1 Blocking-or-painful (would change v0 if fixed)

| # | Missing feature | Impact on v0 | Workaround now |
|---|---|---|---|
| 1 | **No arrays (`DIM`)** | Heap, dictionaries, stacks, class table all simulated via `PEEK`/`POKE`. Every read/write is a pair of arithmetic ops. | Use the 1024-word PEEK/POKE scratch as a flat heap. |
| 2 | **No `DATA`/`READ`/`RESTORE`** | Image is loaded by hundreds of explicit `POKE addr,val` lines. Eats into the 16 KB tokenized program area; readability suffers. | Generate the POKE block from a host script and concatenate. |
| 3 | **No `ON expr GOTO/GOSUB`** | The 14-way bytecode dispatch is a 14-deep `IF`-chain; each opcode pays linear cost in the number of opcodes ahead of it. | Order the chain by expected frequency (PUSH_INT, SEND first). |
| 4 | **No `MOD` operator** | Tag-bit extraction has to use `V - (V/2)*2`. Works, but clutters every type test. | Use the arithmetic identity. |
| 5 | **No bitwise `AND`/`OR`/`XOR`/`SHL`/`SHR`** | Same problem as `MOD`; also blocks compact flag handling and any later bytecode-packing. | Multiply/divide by powers of two. |
| 6 | **No subroutine parameters** | All argument passing is by global variable convention. Easy to break, hard to refactor. | Comment every `GOSUB` site with the register contract. |
| 7 | **`STOP` is fatal (no `CONT`)** | Cannot single-step the VM interactively from the BASIC REPL. | `PRINT` registers and `END`. |

### 11.2 Inconvenient (we can ship around them)

| # | Missing feature | Note |
|---|---|---|
| 8  | Only 26 variables (A-Z). | Sufficient for v0 register file, but extra temps would help. The `A0-Z9` extension already documented in BASIC's `docs/design.md` § 4.2 would be enough. |
| 9  | No multi-statement lines. | Source becomes long; not actually slower. |
| 10 | Token buffer 128 ints, line buffer 80 chars. | Keep BASIC source lines short. |
| 11 | No string variables. | Selectors are integer ids; no problem for v0. |
| 12 | No `RND`. | Demos are deterministic; not needed. |
| 13 | `PEEK`/`POKE` semantics differ above and below 1024 (word-store vs byte-MMIO). | Document the boundary; never use `PEEK`/`POKE` above 1023 from VM code. |
| 14 | `ABS` bug (sw-cor24-basic#1). | Avoid `ABS` until fixed; v0 demos do not need it. |

### 11.3 Upstream feature requests (sw-cor24-basic): all merged

All six FRs filed during step 001 have shipped on
`sw-cor24-basic` `main`. Status of each from this project's
point of view:

- **FR-1** `DIM A(n)` integer arrays — **dogfooded**
  (saga step 010, 2026-04-25). All VM data structures plus the
  bytecode pool are now `DIM` arrays: `H`, `S`, `O`, `P`, `M`,
  `L`, `R`, `Y`, `C`, `G`, `A`, `B`, `K`. Every `PEEK`/`POKE`
  in `vm.bas`, the seven image files, and the seven drivers
  has been removed. Driver top-level bytecode used to live at
  scratch addresses 520/540/600; it now lives at `O()` indices
  8/28/88.
- **FR-2** `DATA` / `READ` / `RESTORE` — **dogfooded**
  (saga step 009, 2026-04-25). Image files dropped 371 -> 98
  lines via the self-describing DATA stream consumed by
  `read_and_install_methods` at `vm.bas` line 10800.
- **FR-3** `ON expr GOTO/GOSUB` — **dogfooded**
  (saga step 011, 2026-04-25). Bytecode dispatch is now two
  `ON O GOSUB` lines (split at O=7 to fit 80-char limit), and
  the primitive trampoline at OP 13 plus its sibling in
  ACTIVATE both became single `ON N GOSUB` lines. O(1) dispatch.
- **FR-4** `MOD` operator — *not yet dogfooded* (saga step
  012). `ISINT` still uses `V - (V/2)*2`.
- **FR-5** bitwise operators — *not yet dogfooded* (saga step
  013). `TOINT`/`MKINT`/`PADDR` still use multiply/divide.
- **FR-6** `CONT` after `STOP` — *not yet dogfooded* (saga
  step 014). No interactive single-stepper exists.

The original "FR list filed against upstream" is preserved in
git history (and in the `minimal-basic-with-workarounds` tag's
annotation) for reference.

## 12. Error Codes

We piggy-back on BASIC v1's error code table where possible:

| Code | Meaning in this VM           | Borrowed from BASIC? |
|------|------------------------------|----------------------|
| 1    | bad bytecode                 | yes (SYNTAX ERROR)   |
| 4    | heap full / stack overflow   | yes (OUT OF MEMORY)  |
| 5    | divide by zero in primitive  | yes (DIV BY ZERO)    |
| 20   | doesNotUnderstand            | new                  |
| 21   | bad selector / arity mismatch| new                  |
| 22   | type mismatch in primitive   | new                  |

The VM stores the code in BASIC variable `E` and prints
`?STERR <code>` before halting.
