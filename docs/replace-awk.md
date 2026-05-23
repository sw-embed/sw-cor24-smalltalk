# Replacing `tools/stc.awk` — Bringing the Compiler Home

_Status: design proposal, 2026-05-09. No code written yet._

## 1. The problem

`tools/stc.awk` is a host-side awk script that compiles `.st` source
into BASIC `DATA` records before the BASIC interpreter ever sees the
program. It runs on the developer's Linux box, not on COR24.

This violates the project's stated purpose. The pitch in `README.md`
is "every step the VM takes is a numbered BASIC line you can
single-step through" — single-stepping the *runtime* but not the
*toolchain*. A user holding a real COR24 FPGA board today can run
`hello.st` (because `vm.bas` is BASIC), but cannot **author**
`hello.st` (because `stc.awk` is awk). Two of the four pipeline
stages do not exist on COR24.

`docs/prd.md` § 7 explicitly forbids C, Python, and Rust in this
repo. Awk is not on that list, but the spirit clearly intended "no
host-side tools at all." This doc plans the work to bring the
compiler onto COR24 and retire awk entirely.

## 2. Current pipeline (truthful)

```
.st source (text)
    |
    v   <-- HOST SIDE (awk, not COR24)
tools/stc.awk  -->  build/<demo>_compiled.bas
                    (image header + DATA-encoded bytecode + driver)
    |
    |   cat with src/vm.bas, append "RUN/BYE"
    v
build/<demo>_full.bas
    |
    v   <-- COR24 SIDE starts here
../sw-cor24-basic/scripts/run-basic.sh
    |
    v
pv24t  (host-side p-code VM emulating COR24; FPGA in production)
    |
    v
basic.pas (compiled to p-code) -- the BASIC interpreter
    |
    v
src/vm.bas (~459 lines of BASIC) -- the Smalltalk VM
    |
    v
Bytecode in scratch RAM (DIM-array indexed)
    |
    v
"hello, world"   etc.
```

The first two stages run on Linux. The last four run on COR24
(emulated or FPGA). The goal is to push the boundary up: ideally
only the *editor* lives off-board.

## 3. How awk got there (the v0.1 story)

Before commit `2936962` (2026-04-26), every demo was hand-assembled
bytecode written directly into a BASIC image file:

```bas
DATA 10, 6, 6, 12, 0, 6, 0, 5, 8     : REM Counter>>init
```

You computed opcode bytes by hand and transcribed them. Painful,
error-prone, and not reusable. `stc.awk` was the v0.1 milestone
deliverable: it lets you write `.st` text and emits the same DATA
records the VM already consumes via `read_and_install_methods`
(`src/vm.bas:10800`). Demos shrank, the seven hand-written
`src/image_d*.bas` files were deleted, and the Smalltalk source
became the canonical authoring surface.

The trade was that authoring moved off COR24. PRD § 6 listed
"self-hosting (compiler-in-Smalltalk)" as out of scope for v0,
which gave implicit cover. Awk's elimination of hand-POKE'd
images was the right tactical move at the time. It is not the
right strategic endpoint.

## 4. Goal

Compile `.st` source to bytecode without leaving COR24. The pipeline
becomes:

```
.st source (text)
    |
    v   <-- COR24 SIDE starts here
emulator / FPGA bootloader copies source bytes into a known
SRAM region
    |
    v
basic.pas runs src/stc.bas (or src/vm.bas's Smalltalk-hosted
Compiler), which PEEKs the source region
    |
    v
Bytecode installed into the heap via the existing method-install path
    |
    v
"hello, world"   etc.
```

`tools/stc.awk` is deleted. `scripts/run-st.sh` shrinks to "load
source into memory; cat vm.bas with a tiny driver; run."

## 5. Hardware reality and memory layout

The COR24 board / emulator has:

- **1 MB SRAM** — main memory, off-chip.
- **3 KB EBR** — FPGA Embedded Block RAM. Fast on-chip storage used
  by the pcode VM as its native call/return stack.

Today's "PEEK 0..1023 = the entire Smalltalk world" convention is a
v0 BASIC expedient. It carved out 1 KB of the 1 MB chip and made it
the only piece of RAM the Smalltalk layer can address. Within that
1 KB it crammed the heap (0..767), the eval stack (768..895), and
the frame stack (896..991). **99.9% of the chip is currently
unused by Smalltalk.**

Replacing awk is a good occasion to revisit the global memory map.
The Smalltalk source window is just one slice of a much larger
address space. Other slices want their own homes too: the pcode
binary, the tokenized BASIC program, the BASIC variable / DATA
region, the Smalltalk object heap, the eval and frame stacks, and
optional overflow space if 3 KB EBR isn't enough for deep pcode
recursion. With 1 MB to spend, none of these need to fight each
other.

### 5.1 Sample global memory map (one option of many)

This is illustrative — a starting point for the conversation with
`sw-cor24-basic` and `sw-cor24-emulator`. Concrete addresses are
their decision; this repo only consumes them.

| Address range          | Size    | Contents |
|------------------------|---------|---------------------------------------|
| `0x00000` - `0x08000`  | 32 KB   | pcode binary (the `.s` file) + statics |
| `0x08000` - `0x10000`  | 32 KB   | tokenized BASIC program area (`vm.bas` + driver) |
| `0x10000` - `0x18000`  | 32 KB   | **Smalltalk source window (`.st` text)** |
| `0x18000` - `0x20000`  | 32 KB   | BASIC variables / `DATA` / `READ` cursor region |
| `0x20000` - `0x80000`  | 384 KB  | Smalltalk object heap |
| `0x80000` - `0xF0000`  | 448 KB  | Smalltalk eval + frame stacks |
| `0xF0000` - `0x100000` | 64 KB   | downward-growing overflow stack (if 3 KB EBR fills) |

Many other partitions are valid. A few alternative shapes worth
considering:

- **Two separate heaps.** A small "VM heap" for short-lived eval-
  stack churn and a large "image heap" for long-lived class
  metadata and instances. Easier GC story later.
- **Per-application data region.** A dedicated slice for application
  state (e.g., the guess game's secret number, the calc REPL's
  history) that survives across `RUN`s if the loader doesn't zero
  it.
- **Multiple source windows.** One for the program being compiled,
  one for the standard library, one for the test corpus. Lets a
  single `RUN` compile and execute against pre-loaded library
  source without re-loading.
- **Larger source window, smaller heap.** Useful for compiling the
  compiler itself (a non-trivial `.st` file) before that file's
  own bytecode evicts it from the source window.

The point is that the memory map is now a **design problem, not a
constraint.** v0 had no choice; v2 has too many.

### 5.2 EBR vs. SRAM

The 3 KB EBR is the pcode VM's native stack — its `CALL`/`RET`
spills land there. It is fast on-chip RAM and doesn't share a bus
with SRAM. It is **not** Smalltalk's frame stack; that lives in
SRAM with the rest of the heap.

3 KB at one pcode-stack-frame per BASIC `GOSUB` is enough headroom
for normal demos. If it ever fills (e.g., very deep BASIC recursion
in a hand-written compiler), the user's option in `5.1` is the
SRAM overflow region: the pcode VM spills the EBR stack into
`0xF0000..0x100000` when EBR is full. That's a `sw-cor24-emulator`
implementation choice; from BASIC's perspective the stack just
keeps working.

### 5.3 Word vs. byte addressing

Today, PEEK below 1024 is **24-bit-word-addressed** (each PEEK
returns a full 24-bit signed word). PEEK above 1024 is documented
as byte-addressed MMIO territory. With 1 MB of SRAM in play, that
distinction matters — and likely needs revisiting.

For the source window specifically, two encodings work:

- **One char per 24-bit word.** PEEK returns the byte directly in
  the low 8 bits, top 16 bits zero. Trivial parser inner loop:
  `IF PEEK(p) = 65 THEN ...`. Wastes 16 bits per char (32 KB
  source uses 96 KB of address space if word-addressed; or
  exactly 32 KB if byte-addressed).
- **Three chars per 24-bit word.** Compact (32 KB source uses
  exactly 32 KB / 11 KB of words), but parser inner loop needs
  shift+mask: `IF (PEEK(p/3) SHR ((p MOD 3) * 8)) BAND 255 = 65`.
  Costs FR-5 bitwise ops (already shipped) and a multiply / mod.

Recommend one-char-per-word for v1 of the source window. Optimise
to packed only if profiling shows the source-region size hurts.

## 6. Loading source onto the board: three mechanisms

| Mechanism | New BASIC feature? | New emulator feature? | Source size cap | FPGA story |
|---|---|---|---|---|
| FR-7 `DATA "..."` literals | Yes (parser+tokenizer) | No | bounded by 16 KB program area | ships once BASIC FR-7 ships |
| FR-8 `INPUT$ A` text input | Yes (parser+runtime) | No | bounded by line buffer | ships once BASIC FR-8 ships |
| **PEEK from loaded SRAM region** | **No** | Yes (loader + memory map) | bounded only by source-window size (32 KB in §5.1) | needs serial / SD bootloader |

### 6.1 Why PEEK-from-loaded-region wins

- **No language extension.** `PEEK` already works. Every byte of
  the approach is something COR24 BASIC v1 can already do.
- **No string variables in BASIC needed.** Source is one byte per
  word — same shape as the existing Smalltalk heap. BASIC v1's
  lack of string vars stops being a blocker.
- **Source size unbounded by the program area.** DATA-encoded
  source competes with the VM and methods for the 16 KB tokenized
  program budget. PEEK'd source lives in its own 32 KB+ region.
- **Faster than DATA streaming.** No `READ` cursor, no per-record
  parsing — direct random-access addressing.
- **Mirrors real systems.** Bootloader puts the bits in RAM;
  program reads them. Same model as Unix `mmap`, an embedded ELF
  loader, or a 1970s minicomputer paper-tape loader. Generalises
  to any future "ship a file to the board" need (test corpora,
  multi-file images, game assets, class library).
- **Plays well with the 1 MB chip.** Carving out a 32 KB source
  window is a rounding error in the address space, not a fight
  for scratch RAM.

### 6.2 Concrete shape (assuming §5.1 addresses)

```
Address (PEEK)     Contents
----------------   ---------------------------------------------
0x10000            Source byte count N (24-bit unsigned)
0x10001            Source byte 0  (one ASCII char per word)
0x10002            Source byte 1
...
0x10000 + N        Source byte N-1
0x10000 + N + 1    0  (sentinel; defensive, for parsers that
                       don't consult the count)
```

A 32 KB source window holds `(0x18000 - 0x10001) = 32767` chars —
big enough for the entire current `.st` corpus several times over,
and big enough for the compiler's own source when self-hosting
arrives.

### 6.3 Open questions

Mostly resolved now that the hardware budget is known:

1. **What is `SRC_BASE`?** Provisionally `0x10000` per §5.1. Final
   value waits on the cross-repo memory-map decision but is no
   longer the bottleneck (any 32 KB-aligned address in SRAM works).
2. **Does PEEK above 1024 currently work for general SRAM?** Open.
   Today's BASIC documents that range as MMIO. Before any code
   lands, `sw-cor24-basic` needs to confirm whether PEEK can be
   extended to address SRAM directly, or whether a new opcode
   (e.g., `SRAM_PEEK`) is required.
3. **How does the emulator accept the load?** CLI flag suggested:
   `pv24t --load <addr> <file> <prog>`. e.g.
   `pv24t --load 0x10000 examples/hello.st build/run.bas`.
4. **How does the FPGA accept the load?** Out of scope. The
   emulator-side mechanism is enough to unblock all software work
   and ship demos. FPGA loading is a `sw-cor24-emulator` (or a
   sibling bootloader project's) concern.
5. **Is the source window writable from BASIC?** Read-only is
   sufficient for the compiler; read-write opens the door to a
   Smalltalk-hosted editor. Default to read-only.
6. **Can the source region be re-loaded mid-run?** Useful for a
   line-at-a-time REPL. Not required for v1 batch compilation.

### 6.4 Why not FR-7 / FR-8?

Both are still useful and may ship anyway:

- **FR-7 (`DATA "string"`)** would let small bootstrap programs
  embed source inline without a loader — handy for built-in demos
  and self-tests that should not depend on the loader being wired
  up. Pure compile-time addition to BASIC's tokenizer.
- **FR-8 (`INPUT$`)** unblocks a true interactive REPL where the
  user types Smalltalk at the prompt. The current D5 calc REPL
  approximates this with integers because BASIC v1 has no string
  `INPUT`. PEEK loading does not solve this — it is for files,
  not for keyboard input.

PEEK loading and FR-7 / FR-8 are complementary, not competing.
PEEK loading is the **primary** mechanism (covers the 95% case of
"compile a `.st` file"); FR-7 / FR-8 cover specialised needs.
Recommended order: PEEK first (unblocks awk removal); FR-7 / FR-8
later if and when their use cases appear.

## 7. Where the compiler lives: three architectures

Loading source is half the problem. The other half is where the
compiler itself runs.

### 7.1 Option A: BASIC-hosted compiler (`src/stc.bas`)

Port `stc.awk`'s 577 lines of awk to BASIC. The BASIC subroutine
reads source bytes via `PEEK(SRC_BASE + i)`, tokenizes, parses,
and emits the same DATA-record bytecode format
`read_and_install_methods` already consumes — except the records
go directly into the heap arrays, not through `READ` from program
DATA.

Cost: ~800-1000 lines of BASIC (BASIC is more verbose than awk;
single-letter variables and no nested data structures).

Constraints: BASIC v1 has no string variables, so all text
manipulation is via integer comparison on PEEK'd bytes. This is
fine for a tokenizer — every state machine operates on
`IF PEEK(p) = 65 THEN ...` style tests. A symbol table is an array
of fixed-width slots indexed by hash.

Pros:
- Smallest leap from today.
- Runs entirely on COR24.
- Uses only features BASIC v1 already has, plus `PEEK` from the
  source window.

Cons:
- Compiler is not in Smalltalk. The "Smalltalk teaches itself"
  story remains incomplete.
- Verbose — single-letter scalars and no records make a parser
  harder to read than the awk equivalent.

### 7.2 Option B: Smalltalk-hosted compiler

Write `Compiler`, `Scanner`, `Parser`, `MethodBuilder` classes in
Smalltalk. The compiler is a Smalltalk program running on the VM,
reading source as a `String` (which v1.0 introduced) constructed
by a tiny BASIC bootstrap from the PEEK'd source bytes, emitting
bytecode by sending messages like `aMethod addByte: 12; addByte: 3`.

This is what Smalltalk-80 famously did and what the 1972 BASIC-
hosted Smalltalk eventually became (per `docs/research.txt`).

Cost: needs several VM additions before the first compiler line
can execute:
- `String at:` — index a string by character position.
- `String size` — character count.
- `ByteArray new: n` — buffer for bytecode under construction.
- `ByteArray at: i put: b` — write a byte.
- `Compiler installMethod: m on: c selector: s` — primitive that
  hands a finished bytecode array to the method dictionary
  (currently the install path is BASIC-only).
- Larger frame stack? The compiler itself recurses (expression ->
  unary -> atom -> expression). Today's 19-frame stack handled D6
  fact at depth 11; a recursive-descent parser may want more
  headroom. With 448 KB of stack space (§5.1), this is no longer
  a real concern — the v0 19-frame limit was a scratch-RAM
  budgeting choice, not a fundamental limit.

Pros:
- The "real" answer. Smalltalk compiles itself.
- Demonstrates the project's central thesis at the toolchain
  level, not just the runtime level.
- Once running, the compiler can be modified in Smalltalk by a
  user on a COR24 board. No re-flashing the BASIC interpreter.

Cons:
- Largest leap. Many VM additions before any compiler code runs.
- Risk of doing it twice if Option A ships first; risk of never
  shipping if Option A is skipped.

### 7.3 Option C: Hybrid bootstrap (recommended)

Do A first, then port to B incrementally.

1. Ship `src/stc.bas` (BASIC-hosted). Awk goes away. The COR24-on-
   FPGA story works end-to-end.
2. Add the VM primitives Option B needs, one demo at a time.
3. Port `Scanner` to Smalltalk first (smallest, most self-contained
   piece of the parser). `src/stc.bas` calls into it via SEND.
4. Port `Parser` to Smalltalk. `src/stc.bas` shrinks.
5. Port `MethodBuilder`. `src/stc.bas` becomes a 50-line stub that
   loads source, sends `Compiler compile: aString`, and installs
   the result.
6. Eventually the stub is replaced by a Smalltalk top-level driver
   that BASIC just `RUN`s. `src/stc.bas` is deleted; only `vm.bas`
   plus a class library remain in `src/`.

Each step ships a working demo. No big-bang rewrite. Each step is
also a real Smalltalk demo in its own right (a tokenizer is a more
interesting program than D6 fact).

## 8. Recommended path

**Memory layout:** carve a 32 KB source window in SRAM at a fixed
address (provisionally `0x10000`). Cross-repo coordination decides
the global map.

**Loading mechanism:** PEEK-from-loaded-region. No new BASIC
features required.

**Compiler architecture:** Option C (hybrid). Ship the BASIC-hosted
compiler first to remove awk and prove the loader works; then
incrementally migrate into Smalltalk.

**Why this combination:** The loader question and the compiler
question are independent. Picking PEEK loading lets us ship
Option A without any new BASIC features. Once Option A is running,
every Smalltalk-hosted compiler step is pure additive work — no
regressions in the demos, no language flag-day.

**What stays out of scope:** FR-7, FR-8, FPGA bootloader, GC,
multiple address spaces. Each is real work but not on the critical
path for awk removal. File when use cases appear.

## 9. Saga plan (proposed)

To be inserted between the current `v1.x-demos` saga and any
follow-on dialect work. Suggested saga name: `replace-awk`.

| # | Step slug | Deliverable |
|---|-----------|-------------|
| 1 | `memory-map-spec` | Decide global SRAM partitioning incl. `SRC_BASE`. Coordinate with `sw-cor24-basic` and `sw-cor24-emulator`. Update `docs/architecture.md` § 3 with the new map. No code. |
| 2 | `basic-sram-peek` | Confirm or extend BASIC PEEK to address SRAM above 1024. May require `sw-cor24-basic` work. Smoke-test: BASIC program PEEKs a known value at `SRC_BASE` and PRINTs it. |
| 3 | `emulator-load-flag` | File issue / PR against `sw-cor24-emulator` for `pv24t --load <addr> <file> <prog>`. Smoke-test: load `examples/hello.st` at `SRC_BASE`, run a one-line BASIC program that PRINTs the byte count from `PEEK(SRC_BASE)` and the first character. |
| 4 | `basic-source-reader` | BASIC subroutine `read_source` that PEEKs the source window and PRINTs each character. Proves the round-trip works on COR24 end-to-end. |
| 5 | `stc-bas-prototype` | Port `stc.awk` tokenizer to `src/stc.bas`. Compile a one-line `.st` program (`main \n 7 print. \n end`) end-to-end on COR24. |
| 6 | `stc-bas-parser` | Add expression parser and method-body compiler to `src/stc.bas`. D1 `3 + 4` runs from `.st` source via `src/stc.bas`. No awk. |
| 7 | `stc-bas-classes` | Add class / slot / inheritance support to `src/stc.bas`. D2..D7 run from `.st` source via `src/stc.bas`. |
| 8 | `stc-bas-strings-and-cascades` | Add string literal and cascade support. `hello.st` runs. |
| 9 | `retire-stc-awk` | Delete `tools/stc.awk`, the `MODE=methods_only` path in `scripts/build.sh`, and the awk-pipeline branch in `scripts/run-st.sh`. Repo has zero awk lines. |
| 10 | `release-v2.0` | Tag `v2.0.0`. Release notes: "compiler runs on COR24." |

Optional follow-on saga `compiler-in-smalltalk` covers Option B's
incremental port.

## 10. Risks

- **R1: Memory-map negotiation drags.** Three projects must agree
  on the global map. Mitigation: write the spec change as a one-
  page PR against `sw-cor24-basic`'s memory-map doc; if it stalls,
  pick a provisional address and commit to revisiting at v2.0.
- **R2: PEEK above 1024 may not address SRAM today.** Today's
  documented behaviour is byte-MMIO. May require a new BASIC
  primitive (`SRAM_PEEK`/`SRAM_POKE`) or a redefinition of PEEK's
  upper range. Mitigation: step 2 of the saga isolates this; a
  small upstream FR is the worst case.
- **R3: BASIC v1's variable scarcity makes the parser unreadable.**
  26 single-letter scalars + 26 single-letter arrays is the whole
  namespace. The Smalltalk VM already uses 13 of each. Mitigation:
  budget step 6 on naming; reuse register letters across non-
  overlapping subroutines (BASIC has no scope, so a discipline
  doc is needed, not a feature).
- **R4: `src/stc.bas` blows the 16 KB program budget.** The VM is
  already 459 lines (~10-12 KB tokenized). A parser of similar
  size could overflow. Mitigation: with the new memory map, the
  BASIC program area can grow past 16 KB (§5.1 budgets 32 KB).
  If even that is tight, split compile-time and run-time into two
  programs that communicate via the heap.
- **R5: We ship Option A and never do Option B.** Self-hosting in
  Smalltalk is the real prize. Mitigation: track Option B as a
  named saga in `docs/status.md` with explicit "not yet started"
  status, not as vague future work.

## 11. What this doc does not decide

- Final values for the global memory-map addresses. §5.1 is
  illustrative.
- Whether PEEK gets extended or a new SRAM primitive is added.
- The wire format for the emulator's load command. CLI shape is
  suggested, not specified.
- Whether the source window is read-only or read-write. Read-only
  is sufficient for the compiler.
- Whether `tools/stc.awk` deletion happens in step 9 or earlier.
  Earlier means losing the safety net of "fall back to awk if
  `src/stc.bas` is broken;" later means living with two compilers
  for the duration of the saga. Step 9 is conservative.

## 12. Decision summary

- **Awk is a v0.1 expedient that violates the project's purpose.**
  It must be removed.
- **The COR24 chip is much bigger than v0 acts like it is** — 1 MB
  SRAM vs. the 1 KB of scratch RAM Smalltalk currently uses. The
  global memory map is up for redesign as part of this work.
- **The right mechanism for getting source onto COR24 is a
  PEEK-readable SRAM region populated by the loader.** It needs
  no new BASIC features (modulo confirming PEEK can address SRAM
  above 1024) and matches how every real system loads programs.
- **The right compiler architecture is hybrid:** ship a BASIC-
  hosted compiler first to remove awk; then port to Smalltalk
  incrementally.
- **The work is one saga (`replace-awk`, ~10 steps) culminating
  in `v2.0.0`.** Optional follow-on saga handles Smalltalk self-
  hosting.
