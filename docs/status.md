# COR24 Smalltalk v0 — Status

_Updated: 2026-04-24 (saga step 006-demo-d5-calc)_

## What runs today

- **Demo D1: `3 + 4` -> `7`** via real `SmallInteger>>+` dispatch
  through `CLASSOF -> LOOKUP -> ACTIVATE -> PRIM 1`. Run with
  `./scripts/run.sh d1_add`.
- **Demo D2: Counter init/incr/incr/value -> `2`** via a
  user-defined class with one instance variable. Exercises
  PUSH_FIELD, STORE_FIELD, frame-stack push in ACTIVATE, and
  RETURN_TOP. Counter>>incr internally invokes `SmallInteger>>+`,
  proving nested message sends across user-method and primitive-
  method boundaries. Run with `./scripts/run.sh d2_counter`.
- **Demo D3: `5 < 10 ifTrue: 42 ifFalse: 0` -> `42`** via True
  and False objects with their own `ifTrue:ifFalse:` methods.
  Exercises PUSH_TEMP (argument access via current-frame's saved
  cleanup_target+1+n), `<` returning the True singleton ref (8),
  and polymorphic dispatch on Boolean class. Run with
  `./scripts/run.sh d3_boolean`.
- **Demo D4: `5 max: 3` -> `5`** via a user-defined method
  `SmallInteger>>max:` that uses `JUMP_IF_FALSE` for *real*
  conditional control flow inside the method's bytecode (not
  D3's eager-argument cheat). Skipping past the unselected branch
  matters for any non-trivial Smalltalk method (recursion,
  loops, guard clauses) — D4 is the smallest demonstration that
  it works. Run with `./scripts/run.sh d4_max`.
- **Demo D5: integer calculator REPL** -- the first interactive
  surface. Prompts for `A`, `op`, `B`; runs `A op B` through the
  VM; prints result; loops until `op = 0`. `op` is the raw
  selector id (1=+, 2=-, 3=*, 4=<, 14=max:). BASIC v1 has no
  string variables, so a true source-text REPL is impossible
  without modifying the host -- this calculator-style front-end
  is the closest interactive surface achievable with the current
  BASIC. `tests/d5_calc.in` is a canned transcript; `scripts/
  build.sh` splices it between the trailing `RUN` and `BYE` so
  `./scripts/run.sh d5_calc` is reproducible.
- All four substrate smoke tests in `examples/smoke/` pass under
  the sibling `pv24t`:
  - `peek_word_store.bas`: PEEK/POKE below 1024 stores full 24-bit
    *signed* words including negatives. (Confirmed; see § "Reality
    check" below for the parser-overflow gotcha discovered while
    writing it.)
  - `tag_bit.bas`: `V - (V/2)*2` extracts the low bit correctly
    for non-negative refs.
  - `gosub_chain.bas`: 14-deep `IF GOSUB` dispatch over 100
    iterations runs in ~30 ms via `pv24t`. Adequate for the demos;
    motivates FR-3 only if we go to bigger images.
  - `prog_size.bas`: 200 `POKE` lines plus loops fit easily in the
    16 KB tokenised program area.

## What exists in this repo

- `CLAUDE.md`, `COPYRIGHT`, `LICENSE`.
- `docs/{prd,architecture,design,plan,status}.md`,
  `docs/research.txt` (research transcript inherited),
  `docs/process.md`, `docs/tools.md`,
  `docs/ai_agent_instructions.md` (placeholders inherited from
  the BASIC repo; cargo-flavoured, will be rewritten when the
  Smalltalk toolchain stabilises).
- `.agentrail/` saga `v0-bootstrap` with 9 steps:
  001-phase-1-bootstrap (in progress, this commit closes it),
  002 demo-d2-counter, 003 demo-d3-boolean, 004
  refactor-image-data (gated on FR-2), 005 refactor-vm-arrays
  (gated on FR-1), 006 refactor-dispatch-on (gated on FR-3),
  007 refactor-mod-and-bits (gated on FR-4 + FR-5), 008
  debug-cont-stepper (gated on FR-6), 009 v0-release-notes.
- `scripts/{build,run,run-bare}.sh`.
- `src/vm.bas` — heap helpers, eval stack, dispatch loop, SEND,
  primitives 1-6 (with primitives 2/3/4/6 untested until D2/D3).
- `src/image_d1.bas` — installs `SmallInteger>>+`.
- `examples/d1_add.bas` — top-level driver.
- `examples/smoke/*.bas` — substrate smoke tests.

## Upstream feature requests filed

In priority order (each unblocks a distinct, parallel-mergeable
saga step here):

| FR | sw-cor24-basic issue | Unblocks step |
|---|---|---|
| FR-2 DATA/READ/RESTORE | sw-embed/sw-cor24-basic#2 | 004-refactor-image-data |
| FR-1 DIM arrays | sw-embed/sw-cor24-basic#3 | 005-refactor-vm-arrays |
| FR-3 ON GOTO/GOSUB | sw-embed/sw-cor24-basic#4 | 006-refactor-dispatch-on |
| FR-4 MOD operator | sw-embed/sw-cor24-basic#5 | 007-refactor-mod-and-bits |
| FR-5 Bitwise ops | sw-embed/sw-cor24-basic#6 | 007-refactor-mod-and-bits |
| FR-6 CONT after STOP | sw-embed/sw-cor24-basic#7 | 008-debug-cont-stepper |

Parallel-development contract: as soon as any FR merges and ships
in `../sw-cor24-basic`, this repo's corresponding refactor step
unblocks and can run independently. The BASIC agent works the FRs
in the order above; this agent picks up whichever refactor
matches whatever just shipped.

## What does not exist yet

- Mini source REPL (saga step 4 in `docs/plan.md`; not yet
  added to the agentrail saga as a separate step).
- `PUSH_LIT` and `STORE_TEMP` — bytecodes reserved in
  `docs/design.md` § 5 but not exercised by any demo and
  currently stubbed (return `E=1`). D2's `init` writes via
  `STORE_FIELD`, not `STORE_TEMP`; no demo needs a literal table
  beyond the inline `PUSH_INT` byte.
- Inheritance / superclass walk in LOOKUP. Single-level lookup
  is enough for D1-D4.
- Real Block closures. v0's `ifTrue:ifFalse:` is eager-arg.
  D4 is the in-method alternative.

## Reality check on the substrate

All five substrate behaviours v0 depends on are now empirically
verified, not just inferred from `basic.pas`:

1. Integer expressions and `LET` — every demo uses these.
2. `IF`, `GOTO`, `GOSUB`/`RETURN`, `FOR`/`NEXT` — exercised by
   smoke tests and the VM dispatch loop.
3. `PEEK`/`POKE` 0..1023 store full 24-bit signed words
   (-8388608..+8388607), confirmed by `peek_word_store.bas`.
   *Caveat discovered in this step*: BASIC v1's integer-literal
   parser silently overflows on values > 8388607 (e.g. the
   literal `16777215` is parsed via repeated `n*10` accumulation
   and wraps), so any image needing the full positive range must
   compute the value in BASIC rather than write it as a literal.
   The smoke test now uses 8388607, 1048576, 65536, 255, -1.
4. `PRINT` of a SmallInt outputs no leading space and a trailing
   newline — perfect for primitive 5 (`print`).
5. The 16 KB tokenised program area easily holds image + VM +
   driver: D1's combined source is 346 lines, well under the cap.

Known substrate bug: `ABS` is broken (sw-cor24-basic#1). v0
does not use `ABS`.

## Immediate next step

The three foundational demos all run. Two natural next steps,
both already queued in the saga:

- Steps 004-008 are the *parallel-development pipeline*: each
  one unblocks once the corresponding upstream FR (BASIC issues
  #2-#7) merges. Best to wait on those rather than block on
  them.
- Step 009-v0-release-notes is *not* gated on anything upstream
  and would write the first `README.md` plus tag `v0.0.1`. This
  is the cleanest "we are done with the v0 bootstrap" milestone
  and a good place to pause.

## Out of scope (also see `prd.md` § 6)

- A general Smalltalk parser, real Block closures, GC,
  metaclasses, image save/load, the visual tile editor.
- Any C, Python, or Rust source in this repo.

## Decision log

- 2026-04-24: project created.
- 2026-04-24: hosting language for v0 is BASIC (the sibling
  `sw-cor24-basic` v1 dialect). The Smalltalk VM will be a
  ~1000-line BASIC program, mirroring the historical 1972
  BASIC-hosted Smalltalk evaluator described in
  `docs/research.txt`.
- 2026-04-24: heap and dictionaries live in BASIC's PEEK/POKE
  scratch RAM (1024 24-bit words). The 26 BASIC variables A-Z
  serve as VM registers (mapping in `architecture.md` § 3).
- 2026-04-24: bytecode set frozen at 14 opcodes for v0
  (`design.md` § 5).
- 2026-04-24: agentrail saga `v0-bootstrap` initialised with 9
  steps; FRs filed against `sw-cor24-basic` (#2-#7) for
  parallel-development pipeline.
- 2026-04-24: D1 working — first end-to-end Smalltalk message
  send (`3 + 4` -> `7`) hosted on integer-only BASIC.
- 2026-04-24: simplification: primitive methods bypass frame
  activation entirely. ACTIVATE detects bodies starting with
  opcode 13 (PRIMITIVE) and dispatches inline. D1 therefore
  needs no frame stack at all; D2/D3 will introduce it for
  user-defined methods.
- 2026-04-24: D2 working — Counter with PUSH_FIELD/STORE_FIELD,
  frame stack at addresses 896..991 (5 words/frame, 19 frames
  max), RETURN_TOP that restores caller P/M/L/R/S and
  back-fills the result at the saved cleanup target. Nested
  send (`incr` calling `SmallInteger>>+`) works.
- 2026-04-24: D3 working — Boolean dispatch via True/False
  objects with their own `ifTrue:ifFalse:` methods. PUSH_TEMP
  reads args via `(current frame's saved cleanup_target) + 1 +
  n`. Block evaluation is *eager* in v0: callers compute both
  branches and pass them as arguments; the receiver class
  selects which one to return.
- 2026-04-24: D4 working — `5 max: 3` -> 5 via a user-defined
  `SmallInteger>>max:` method whose bytecode uses
  `JUMP_IF_FALSE` to skip past the unselected branch. Both
  `5 max: 3` and `3 max: 5` were verified before the canonical
  driver was settled on the former. JUMP and JUMP_IF_FALSE both
  read the operand byte then add it to P; for offsets in scratch
  RAM, PEEK returns the full signed 24-bit word, so backward
  jumps work natively without sign-extension tricks.
- 2026-04-24: D5 working — interactive integer calculator REPL.
  PRIM 5 (print) extended to print booleans (`TRUE`, `FALSE`)
  and `NIL` rather than raising E=22 on a heap ref; the smallint
  fast path is unchanged. Discovered (and fixed) a line-number
  collision: image_d5 used line 200 (`LET B=13` for max:'s
  install) and the original driver used 200 as its exit label
  (`PRINT "BYE"`); BASIC's last-write-wins line storage replaced
  the install. New rule: image files use 100..299 (or 100..499);
  drivers must keep their exit labels at 800+ to leave room.
  Also added a generic test-input splice mechanism in build.sh:
  if `tests/&lt;demo&gt;.in` exists, it is automatically inserted
  between the trailing `RUN` and `BYE` so interactive demos are
  reproducible.
