# Step: phase-1-bootstrap

Stand up COR24 Smalltalk v0 to the point where demo D1 (`3 + 4`)
runs end-to-end through real Smalltalk message dispatch on the
sibling BASIC interpreter, AND file the upstream BASIC feature
requests so the BASIC repo agent can start work in parallel.

## Read first
- `docs/prd.md` (scope and constraints)
- `docs/architecture.md` (layer model, memory map)
- `docs/design.md` (object encoding, bytecode, dispatch — § 11
  has the BASIC v1 shortcomings that drive the FR list)
- `docs/plan.md` (phases 2-7)
- `../sw-cor24-basic/CLAUDE.md`, `../sw-cor24-basic/README.md`,
  `../sw-cor24-basic/src/basic.pas` (especially lines 110-160 and
  290-300 for PEEK/POKE word-store semantics)

## Constraints
- No C, Python, or Rust source in this repo.
- Only BASIC source under `src/`, `examples/`. Shell under
  `scripts/`.
- Don't modify anything in `../sw-cor24-basic`. File issues against
  it instead.

## Deliverables
1. `.gitignore` (build artifacts, OS noise).
2. `scripts/build.sh`: cat `src/vm.bas` + per-demo image header into
   `build/<demo>.bas`.
3. `scripts/run.sh`: build then invoke
   `../sw-cor24-basic/scripts/run-basic.sh build/<demo>.bas`.
4. `examples/smoke/peek_word_store.bas`,
   `examples/smoke/tag_bit.bas`,
   `examples/smoke/gosub_chain.bas`,
   `examples/smoke/prog_size.bas`. Each is a standalone BASIC
   program (does not need vm.bas) that confirms one substrate
   property the v0 design depends on. See `docs/plan.md` § Phase 2
   for what each one tests.
5. `src/vm.bas`: heap helpers (1000-1499), stack helpers
   (1500-1999), dispatch loop (2000-2999), opcode handlers
   (3000-3999), SEND/LOOKUP (4000-4499), primitives 1 (`+`) and
   5 (`print`) (4500-4999). Layout matches
   `docs/architecture.md` § 7. Liberal `REM` comments because the
   code is the teaching artefact.
6. `src/image_d1.bas`: install class table, install
   `SmallInteger>>+` (selector id 1, primitive 1).
7. `examples/d1_add.bas`: top-level driver that hand-assembles the
   `3 + 4` bytecode into the bytecode pool, calls the dispatch
   loop, prints `7`.
8. Run D1 via `scripts/run.sh d1_add` and confirm output is `7`.
9. File 6 GitHub issues against `sw-cor24-basic` for FR-1..FR-6 in
   the order listed in `docs/plan.md` § Upstream feature requests.
   Each issue:
   - Title: `[FR-N] <feature>`
   - Body links back to `sw-cor24-smalltalk/docs/design.md` § 11
     and to the specific refactor step in this saga that the FR
     unblocks (refactor-image-data, refactor-vm-arrays,
     refactor-dispatch-on, refactor-mod-and-bits,
     debug-cont-stepper).
   - Includes a one-paragraph "why this matters for hosting
     Smalltalk in BASIC" so the request isn't generic.

## Definition of done
- D1 prints `7` via real `SmallInteger>>+` dispatch (not via
  `PRINT 3+4`).
- All four smoke tests run cleanly under sibling pv24t.
- Six issues open against `sw-embed/sw-cor24-basic` with the
  correct titles and labels.
- `git commit` of all generated source plus `.agentrail/` step
  artefacts.
