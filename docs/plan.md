# COR24 Smalltalk v0 — Implementation Plan

This is the step-by-step plan to build the three demo programs
described in `docs/prd.md` and the VM described in `docs/design.md`.
The plan is intentionally small: v0 is a teaching prototype, not a
production language.

The work is organised so the user can stop at the end of any phase
and have something runnable.

## 0. Toolchain & Constraints

- **Hosted in BASIC.** All v0 source files in this repo end `.bas`.
  No C, Python, or Rust here.
- **BASIC is the sibling project `../sw-cor24-basic`.** It is
  treated as a fixed substrate; we file feature requests there but
  do not modify it from this repo.
- **Build = text concatenation.** A demo is one or more `.bas`
  files cat'd together and run through `pv24t` via the BASIC
  project's `scripts/run-basic.sh`.

```
docs/research.txt and PRD/architecture/design  (this phase, done)
        |
        v
src/vm.bas  +  src/image_<demo>.bas  +  examples/<demo>.bas
        |
        v
scripts/build.sh  (cat them together)
        |
        v
build/<demo>.bas
        |
        v
../sw-cor24-basic/scripts/run-basic.sh build/<demo>.bas
```

## Phase 1 — Specification (this phase)

Deliverables:

- [x] `CLAUDE.md` (renamed from AGENTS.example.md).
- [x] `docs/prd.md`.
- [x] `docs/architecture.md`.
- [x] `docs/design.md`.
- [x] `docs/plan.md` (this document).
- [x] `docs/status.md`.
- [x] BASIC v1 shortcomings catalogued (`docs/design.md` § 11).

Exit criterion: the user can read these five docs end-to-end and
see exactly which BASIC line numbers will hold the VM.

## Phase 2 — Substrate Smoke Test

Before writing the VM, validate the host. Each item is a tiny
`.bas` program saved in `examples/smoke/` and run through
`run-basic.sh`. Each is a *learning test* about a BASIC v1 quirk
that the VM relies on.

- **2.1** `peek_word_store.bas`: prove that `POKE 100, 16777215` /
  `PRINT PEEK(100)` round-trips a 24-bit value when address < 1024.
  (Confirms the word-store-vs-byte-MMIO boundary documented in
  `design.md` § 11.2 #13.)
- **2.2** `tag_bit.bas`: prove `V - (V/2)*2` correctly extracts the
  low bit of `V` for both even and odd values, including small
  negatives.
- **2.3** `gosub_chain.bas`: measure roughly how long a 14-deep
  `IF`-chain `GOSUB` dispatch takes per iteration (informational —
  motivates FR-3 from `design.md` § 11.3 if the answer is bad).
- **2.4** `prog_size.bas`: write a deliberately large program with
  ~600 `POKE` lines and confirm it fits in the 16 KB token area.
  (Sets the upper bound on how big a hand-built image can be.)

Exit criterion: each smoke-test runs cleanly under `pv24t`. Any
failure here gets a corresponding upstream issue in
`sw-cor24-basic` *before* we proceed.

## Phase 3 — Heap Helpers and Object Encoding

Build `src/vm.bas` lines 1000-1499. No bytecode interpretation
yet — just the substrate.

- **3.1** Implement `ISINT`, `TOINT`, `MKINT`, `ISPTR`, `PADDR`
  helpers (`design.md` § 2.1).
- **3.2** Implement `ALLOC` (`design.md` § 3.2). Initialise `H = 16`
  on `RUN`.
- **3.3** Install canonical singletons (nil, true, false) into
  scratch addresses 0..15.
- **3.4** Implement `CLASSOF` (`design.md` § 4 / line 4600).
- **3.5** Add a tiny self-test driver: `RUN` the program, allocate
  an Object of size 2, print its heap address, confirm `CLASSOF`
  returns 0.

Exit criterion: the program can allocate, tag, untag, and identify
the class of arbitrary objects without invoking any of the VM
opcodes.

## Phase 4 — Eval and Frame Stacks

`src/vm.bas` lines 1500-1999.

- **4.1** Implement `EPUSH` and `EPOP` (eval stack at addr
  768..895). Convention: `V` is the value to push, `T` is the
  popped value.
- **4.2** Implement `FPUSH` and `FPOP` for the frame stack at
  addresses 896..991. A frame is six words (`design.md` § 7).
- **4.3** Self-test: push 10 SmallInts, pop them, verify the LIFO
  order. Push and pop a frame, verify all six fields round-trip.

## Phase 5 — Bytecode Dispatch (no SEND yet)

`src/vm.bas` lines 2000-3699.

- **5.1** Write the fetch/decode/execute loop (`architecture.md`
  § 5).
- **5.2** Implement opcode handlers that don't need send: HALT,
  PUSH_SELF, PUSH_LIT, PUSH_TEMP, STORE_TEMP, PUSH_FIELD,
  STORE_FIELD, RETURN_TOP, POP, JUMP, JUMP_IF_FALSE, PUSH_INT.
- **5.3** Self-test: hand-assemble a 4-byte program
  `0C 0A 0D 05 00` (PUSH_INT 10; PRIMITIVE 5 (print); HALT) into
  the bytecode pool and run it. Should print `10`.

(Note: this *does* exercise PRIMITIVE 5 even though SEND isn't
done yet — primitives are invoked directly from the dispatch loop,
not through send.)

## Phase 6 — Method Dictionary and SEND

`src/vm.bas` lines 3700-4499.

- **6.1** Implement `LOOKUP` (`design.md` § 6.1).
- **6.2** Implement `SEND` (`design.md` § 7), including frame push
  and `doesNotUnderstand:` dispatch.
- **6.3** Implement `RETURN_TOP` to pop a frame and restore
  `P/B/L/M/R`.
- **6.4** Self-test: install a method `Object>>print` whose body is
  `PRIMITIVE 5; RETURN_TOP`. Issue `SEND 5,0` against a SmallInt
  receiver. Should print the integer and not crash.

## Phase 7 — Demo D1: `3 + 4`

`src/image_d1.bas` + driver in `examples/d1_add.bas`.

- **7.1** Image: install `SmallInteger>>+` whose body is
  `PRIMITIVE 1; RETURN_TOP`. Selector id 1.
- **7.2** Driver: hand-assembled bytecode
  `0C 03 0C 04 07 01 01 0D 05 00`
  (PUSH_INT 3; PUSH_INT 4; SEND '+',1; PRIMITIVE 5; HALT).
- **7.3** Run: should print `7`.
- **7.4** Document any deviations from the design and fold back
  into `design.md`.

Exit criterion: D1 runs end-to-end through real message-send
dispatch. This is the project's first claim of being "Smalltalk".

## Phase 8 — Demo D2: Counter

`src/image_d2.bas` + `examples/d2_counter.bas`.

- **8.1** Install class `Counter` at class id 10. instance var
  count = 1 (`value`).
- **8.2** Install methods:
  - `Counter>>init`: bytecode `0C 00 06 00 01 08`
    (PUSH_INT 0; STORE_FIELD 0; PUSH_SELF; RETURN_TOP).
  - `Counter>>incr`: bytecode `05 00 0C 01 07 01 01 06 00 01 08`.
  - `Counter>>value`: bytecode `05 00 08`.
- **8.3** Driver: allocate Counter, send `init`, `incr`, `incr`,
  `value`, then `print`. Should print `2`.

Exit criterion: D2 demonstrates that user-defined classes work and
that messages dispatch by *receiver class*, not by syntax.

## Phase 9 — Demo D3: Boolean dispatch

`src/image_d3.bas` + `examples/d3_boolean.bas`.

- **9.1** Install `True>>ifTrue:ifFalse:` and
  `False>>ifTrue:ifFalse:`. v0 cheats: blocks are method literals,
  not real closures. Each `ifTrue:ifFalse:` body picks the
  appropriate literal index and `RETURN_TOP`s a SmallInt directly.
- **9.2** Install `SmallInteger>>< ` (primitive 4). The primitive
  pushes either `true` (heap addr 4 -> ref 8) or `false` (heap
  addr 8 -> ref 16) onto the eval stack.
- **9.3** Driver: hand-assembled `5 < 10 ifTrue: [42] ifFalse: [0]`.
  Should print `42`.

Exit criterion: D3 demonstrates polymorphic dispatch through True
and False objects, the central trick that lets Smalltalk avoid
native `IF`.

## Phase 10 — Mini REPL (Optional)

`src/repl.bas`. Only built if Phases 7-9 are clean.

- **10.1** Read a line via `INPUT`. Match the three demo grammars.
- **10.2** Compile the matched grammar to bytecode and execute.
- **10.3** Loop until the user types `BYE`.

This is non-essential — the demos already prove the VM works. The
REPL is a nicer surface for the user to play with the result.

## Phase 11 — Documentation Pass

- Update `docs/status.md` with what was actually built.
- Add a `README.md` (only when the demos run; not before).
- Add a small `examples/README.md` index of demo scripts.

## Upstream Feature Requests (file in `sw-cor24-basic`)

These are in priority order for unblocking *this* project. They
match `docs/design.md` § 11.3 (FR-1 .. FR-6). v0 does not require
any of them; v1 (or a sane v0.1) probably wants FR-1 and FR-3.

| FR  | Title                          | Why this project wants it                                  |
|-----|--------------------------------|------------------------------------------------------------|
| FR-1| `DIM A(n)` integer arrays      | Replace PEEK/POKE-as-array; biggest readability win        |
| FR-2| `DATA`/`READ`/`RESTORE`        | Image load as data block instead of POKE-per-line          |
| FR-3| `ON expr GOTO/GOSUB list`      | O(1) bytecode dispatch instead of an IF-chain              |
| FR-4| `MOD` operator                 | Clean tag-bit extraction                                   |
| FR-5| Bitwise ops (`SHL`/`SHR`/`AND` (bitwise)/`OR` (bitwise)/`XOR`) | Compact tag/format encoding for v1               |
| FR-6| `CONT` after `STOP`            | Single-step the VM from the BASIC REPL                     |

When filing each, link back to:

- `sw-cor24-smalltalk/docs/design.md` § 11.3 (the catalogue),
- the specific Phase in this plan that would be cleaner with it,
- and a one-paragraph use-case from this VM (don't open generic
  feature requests — show *why* it would help an actual user).

## Risks

- **R1**: The 16 KB tokenised program area might be too small for
  `image_load + vm + repl` together. Mitigation: ship one demo per
  binary, share `vm.bas` by concatenation. If even single demos
  exceed the cap, we file a "raise PS" feature request upstream.
- **R2**: A 14-deep IF-chain dispatch may be too slow even for
  these tiny demos. Mitigation: measure in Phase 2.3; if bad, file
  FR-3 and ship anyway because correctness is the gate, not speed.
- **R3**: BASIC's `PEEK`/`POKE` *byte vs word* semantics could trip
  up a future user trying to extend the heap above 1024. Mitigation:
  Phase 2.1 documents this as the *first* smoke test, and
  `design.md` § 11.2 calls it out explicitly.
- **R4**: `ABS` bug (sw-cor24-basic#1) could be triggered by
  accident. Mitigation: do not use `ABS` anywhere in v0; rely on
  the documented fact that all SmallInt operands are non-negative
  in the demos.

## Definition of Done (v0)

- D1, D2, D3 all run cleanly under `pv24t` and produce the expected
  output.
- No code in this repo is C, Python, or Rust.
- `docs/status.md` reflects the truth: what runs, what doesn't,
  what's the next step.
- The list of upstream feature requests is filed (or at least drafted
  in this repo).
