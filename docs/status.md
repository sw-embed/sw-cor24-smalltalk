# COR24 Smalltalk v0 — Status

_Updated: 2026-04-26 (saga step 016-migrate-demos-to-st)_

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
- **Demo D6: `5 fact` -> `120`** via a real recursive
  `SmallInteger>>fact` method. Uses the `JUMP_IF_FALSE` pattern
  from D4 (must, since blocks are eager in v0; an `ifTrue:ifFalse:`
  fact would loop forever computing `(self - 1) fact` even at the
  base case). Stress-tested up to `10 fact = 3628800` -- recursion
  depth 11, well within the 19-frame stack. First proof that the
  frame stack handles non-trivial nesting. Run with
  `./scripts/run.sh d6_fact`.
- **Demo D7: BoundedCounter -> `5`** via inheritance. A
  `BoundedCounter` (class id 11) extends `Counter` (10) and
  overrides `incr` to cap at 5; `init` and `value` are inherited
  via a superclass walk added to LOOKUP. After 6 incrs from 0,
  the value clamps at 5. Proves: (a) the receiver's class wins
  on dispatch (incr resolves to BoundedCounter's override); (b)
  missing methods walk `class_super[]` at addresses 752..767
  until the chain terminates at -1 (set by INSTALL_SINGLETONS
  for class 0).
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

## Known wart: stale `BLOCKED until …` saga prompts

Steps `010-refactor-vm-arrays`, `011-refactor-dispatch-on`,
`012-refactor-mod-and-bits`, and `014-debug-cont-stepper` all
have prompts that begin "BLOCKED until `sw-cor24-basic` issue
[FR-N] … ships". Those prompts were written before any FR
landed.

All six FRs are now closed and merged on
`sw-cor24-basic`'s `main` (commits `99412f7` FR-2, `e20cabc`
FR-1, `f60ec3a` FR-3, `c6d3080` FR-4, `8ab3654` FR-5,
`3f82f3b` FR-6). `agentrail` has no edit-prompt command, so
the stale wording remains in the step record.

**An agent picking up any of those steps must check
`../sw-cor24-basic` git log first** to confirm the gating
dependency is satisfied before treating the prompt's "BLOCKED"
language at face value. Steps `009-refactor-image-data`,
`013-refactor-bitwise`, and `015-v0.1-release-notes` were
written or refreshed after the FRs landed and don't carry
this wart.

## Future sagas (post-v0.1)

The following issues describe work that doesn't fit the
`v0-bootstrap` saga's "Tinytalk + dogfood the BASIC FRs" charter
and will anchor future sagas after `v0.1.0` tags.

### v1-dialect saga (next)

Tracking issues:
- [`sw-cor24-smalltalk#2`](https://github.com/sw-embed/sw-cor24-smalltalk/issues/2)
  — Dialect roadmap (v1 strings → v7 processes).
- [`sw-cor24-smalltalk#4`](https://github.com/sw-embed/sw-cor24-smalltalk/issues/4)
  — v1: strings + literal pool + `Transcript`.
- [`sw-cor24-smalltalk#3`](https://github.com/sw-embed/sw-cor24-smalltalk/issues/3)
  — Demo: `guess` (depends on v1 strings).
- [`sw-cor24-smalltalk#5`](https://github.com/sw-embed/sw-cor24-smalltalk/issues/5)
  — Compiler: full Smalltalk-source -> bytecode. Partially
  delivered by current saga steps 015 + 016 (minimal subset
  covering D1..D7); full scope (cascades, standard precedence,
  block literals, literal pool) extends through the v1 saga and
  beyond.

Anchor work: add `String` class, generalize `PUSH_LIT` to a typed
literal pool, ship `Transcript show:` / `cr`, port `D5 calc` so
output reads `3 + 4 = 7` instead of `7`. Then port `guess` to
`.st` and ship as the first interactive game.

Initial step list (sketch — to be refined when `agentrail init`
ed):

1. `dialect-v1-strings-spec` — design Symbol vs String, literal
   pool layout, new bytecodes.
2. `dialect-v1-strings-vm` — implement String/Symbol heap
   format, generalize PUSH_LIT, add Transcript primitive.
3. `dialect-v1-image-format` — extend the FR-2 DATA stream to
   carry literal pool entries.
4. `dialect-v1-compiler` — extend `stc` to compile string
   literals + `Transcript show:` calls.
5. `dialect-v1-d5-rewrite` — make D5 calc print `A op B = C`.
6. `dialect-v1-guess-demo` — port `guess` from BASIC.
7. `dialect-v1-release` — tag `v1.0.0`.

### v0-extras saga (optional, before v1)

Tracking issue:
[`sw-cor24-smalltalk#1`](https://github.com/sw-embed/sw-cor24-smalltalk/issues/1)
— Demo backlog (v0-feasible).

Step `017-demo-backlog-v0-fib-gcd-list` lands three of these in
the current saga (fibonacci, gcd, linked-list). The remaining
seven (power, prime, ackermann, hanoi, stack/queue,
state-machine, compare-mixin) could either:

- ship as a standalone `v0-extras` saga between v0.1 and v1, or
- land alongside the v1-dialect work as a richer demo gallery.

No urgency — they don't block v1. The issue's checklist is the
canonical scoreboard.

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
- 2026-04-24: D6 working — `5 fact -> 120` via real recursive
  `SmallInteger>>fact`. The trick is `JUMP_IF_FALSE` (eager
  blocks would loop forever in `ifTrue:ifFalse:` fact). Verified
  to `10 fact = 3628800` (depth-11 recursion). No new VM features
  needed.
- 2026-04-26: All seven foundational demos migrated to `.st`
  source. `src/image_d{1,2,3,4,5,6,7}.bas` deleted; the only
  remaining `.bas` source under `src/` is `vm.bas` itself.
  `examples/d*.st` is now the canonical place where Smalltalk
  text lives in the repo.
  Compiler extensions in `tools/stc.awk` for this step:
  - `args A B ...` declares method arguments. Atom resolution
    looks up arg names before slot names; both use `PUSH_TEMP`
    or `PUSH_FIELD` accordingly.
  - `class CHILD extends PARENT` inherits parent's slot list
    and emits `LET K(child) = parent` into the image header.
  - `if EXPR` guards the next `^` statement with
    `JUMP_IF_FALSE`, backpatching the offset when the `^`
    fires. Multiple statements between `if` and `^` all become
    part of the guarded block; this is what D7
    `BoundedCounter>>incr` uses.
  - Atom precedence: paren-grouped expressions and unary
    sends. `(self - 1) fact` now parses as expected
    (binary inside parens, then unary `fact`). Required for
    D6 fact's `self * (self - 1) fact` recursive expression.
  - DATA-line chunking: long method bodies (D6 fact at 25
    bytes, D7 incr at 22 bytes) get split across multiple
    DATA lines so each stays under BASIC's 80-char input
    limit. `read_and_install_methods` (vm.bas:10800) walks
    DATA in source order regardless of line boundaries, so
    no VM change.
  D8 stepper reuses D1's source (build.sh maps `d8_step` to
  `examples/d1_add.st`).
- 2026-04-26: First Smalltalk-source compiler — `tools/stc.awk`
  reads a `.st` file and emits the same DATA-record image format
  the VM consumes. Verified on D2 (Counter): the generated image
  diffs against the hand-written `src/image_d2.bas` only at the
  REM header — every byte of method bytecode is identical. New
  files: `tools/stc.awk` (180 lines awk), `examples/d2_counter.st`
  (12 lines Smalltalk), `docs/st-source.md` (syntax reference).
  `scripts/build.sh` now invokes `stc` automatically when an
  `.st` file exists for the demo. v0 syntax subset: class with
  named slots, methods, `^ expr`, `var := expr`, `primitive N`,
  atoms (self / int / slot), left-to-right binary sends. No
  precedence, cascades, blocks, keyword sends, or strings yet
  (those go in step 016 + the v1-dialect saga).
- 2026-04-26: FR-6 (CONT after STOP) dogfooded — added a
  scalar `J` flag to the dispatch loop. When `J <> 0`, the
  loop calls `STOP` before every opcode fetch, returning to
  the BASIC immediate prompt. The user can `PRINT P,M,L,R,S,F`
  (or any DIM array slot) to inspect VM state, then `CONT` to
  advance one opcode. Default behaviour (J=0) is unchanged for
  D1-D7. New `examples/d8_step.bas` is D1's `3 + 4` with
  stepping enabled; `tests/d8_step.in` provides a canned
  PRINT/CONT transcript that captures the state at every step:
    STEP P=0 S=0      (before first opcode)
    STEP P=2 S=1      (after PUSH_INT 3)
    STEP P=4 S=2      (after PUSH_INT 4)
    STEP P=7 S=1      (after SEND '+' produced 7)
    STEP P=9 S=1      (after PRIMITIVE 5 printed 7)
- 2026-04-26: FR-5 (bitwise) dogfooded — TOINT, MKINT, PADDR
  in `src/vm.bas` now use `SHR`/`SHL`/`BOR` instead of `*2`/`/2`
  arithmetic:
  - `TOINT`:  `T = V SHR 1`     (was `(V-1)/2`)
  - `MKINT`:  `T = (V SHL 1) BOR 1`  (was `V*2 + 1`)
  - `PADDR`:  `T = V SHR 1`     (was `V/2`)
  ISINT was kept on `V MOD 2` from FR-4 (`V BAND 1` would also
  work and would handle negative tagged refs slightly more
  cleanly, but no v0 demo uses negative SmallInts).
  Smoke test confirmed equivalent values for the cases v0
  exercises.
- 2026-04-25: FR-4 (MOD) dogfooded — ISINT helper now reads
  `T = V MOD 2` instead of `T = V - (V/2)*2`. One-line change.
  This was originally bundled with FR-5 (bitwise) in saga step
  012; the bitwise half is now its own step (013).
- 2026-04-25: FR-3 (ON expr GOTO/GOSUB) dogfooded — three
  IF-chains in `src/vm.bas` collapsed to single-line dispatchers:
  - main bytecode dispatch (was 14 IFs at lines 12060..12200)
    -> two `ON GOSUB`s split at O=7 (BASIC's 80-char line limit
    can't fit a 13-target list on one line; "ON O GOSUB
    13100,13200,..." with 13 entries comes to ~94 chars).
  - OP 13 PRIMITIVE handler (was 6 IFs at 14310..14380)
    -> one `ON N GOSUB 15100,15200,...,15600` line.
  - ACTIVATE primitive-method path (was 6 IFs at 14600..14670)
    -> same single-line ON GOSUB.
  Hot-path opcode dispatch now O(1) instead of O(n).
  vm.bas:  396 -> 380 lines (-16).
- 2026-04-25: FR-1 (DIM) dogfooded — every PEEK/POKE in the VM,
  images, and drivers replaced by indexed array access. The VM
  uses 13 single-letter arrays (`H`, `S`, `O`, `P`, `M`, `L`,
  `R`, `Y`, `C`, `G`, `A`, `B`, `K`), each one named to match
  the scalar register that meaningfully indexes it. BASIC v1's
  scalar-vs-array namespace separation lets `M` the scalar
  (current method's bcstart index) and `M` the array (saved
  method addrs per frame) coexist without conflict. Discovered
  during phase 1 that BASIC v1 only allows single-letter
  variable names — my initial `DIM HP(511)` failed because `HP`
  tokenized as scalar `H` followed by scalar `P`. Forced a full
  redesign of the array-name plan around single letters.
  Bytecode pool became `O(0..127)`; absolute scratch addresses
  512..639 are gone — every driver now writes top-level
  bytecode at indices 8/28/88 (was 520/540/600). Result:
  `grep -c "PEEK\\|POKE" src/*.bas examples/*.bas` reports 0.
- 2026-04-25: First FR dogfooded — image loaders now use FR-2
  (DATA/READ/RESTORE) instead of one POKE per byte. Added shared
  helper `read_and_install_methods` at `src/vm.bas` line 10800
  that consumes a self-describing DATA stream:
  `<class> <selector> <byte-count> <byte0> ... <byte_n-1>`,
  terminated by `<-1>`. Each `image_d*.bas` shrank dramatically:
  371 lines total -> 98 lines (74% reduction). All 7 demos still
  produce identical output (7, 2, 42, 5, REPL, 120, 5). The
  contiguous-pool layout means method bytecode addresses are now
  determined by DATA order, not by hand; verified that nothing
  else in the VM cares about the exact addresses (everything
  references methods through (class, selector) lookup).
- 2026-04-24: D7 working — inheritance via superclass walk.
  `class_super[]` lives at scratch addresses 752..767;
  INSTALL_SINGLETONS now sets `class_super[0] = -1` so the chain
  terminates at Object. LOOKUP retries on each superclass on
  miss; bug fix: previous LOOKUP wrote `T = -1` instead of
  `Q = -1` on no-match (latent because D1-D6 never missed).
  Driver line-collision class of bug bit again: D7 driver
  initially used line 800 for END which forced execution to fall
  through image's lines 100-299 a second time after dispatch
  returned, triggering an out-of-balance RETURN. Fixed by
  putting END at line 99 so execution halts cleanly before
  re-entering the image's range.
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
