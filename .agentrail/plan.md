# Saga: v0-bootstrap

Bring up COR24 Smalltalk v0 — a minimal integer-only Tinytalk-style
VM hosted entirely in COR24 BASIC v1, in the spirit of the
~1000-line BASIC-hosted Smalltalk evaluator that Alan Kay's group
built in 1972 (see `docs/research.txt`).

Constraint: no C, no Python, no Rust in this repository. The VM is
written in BASIC; the BASIC interpreter itself is a sibling project
(`../sw-cor24-basic`, written in Pascal) and is treated as a fixed
substrate.

## Goal

Three runnable demos that prove the object/message/dispatch model:
- D1: `3 + 4` evaluated as a real `SmallInteger>>+` send (prints 7).
- D2: a Counter class with `init`/`incr`/`value` (prints 2).
- D3: `5 < 10 ifTrue: [42] ifFalse: [0]` via True/False objects
  (prints 42).

## Steps

### 1. phase-1-bootstrap

Stand up everything needed to run D1 (`3 + 4`) end-to-end against
the sibling `../sw-cor24-basic` interpreter:

- `.gitignore`, `scripts/build.sh`, `scripts/run.sh` wrapping the
  sibling's `run-basic.sh`.
- Phase-2 smoke tests in `examples/smoke/` validating the four
  BASIC v1 substrate behaviours v0 depends on (see
  `docs/plan.md` § Phase 2).
- `src/vm.bas`: heap helpers, eval/frame stacks, dispatch loop,
  SEND, LOOKUP, primitives 1 and 5.
- `src/image_d1.bas`: install `SmallInteger>>+` (primitive 1).
- `examples/d1_add.bas`: driver that issues the `3 + 4` send.
- A sibling-substrate sanity check (build + run a single demo).

Also file the upstream feature requests against
`sw-cor24-basic` (see step `upstream-feature-requests` below) at
the end of this step so the BASIC agent can start work in parallel.

### 2. demo-d2-counter

Add a user-defined class with one instance variable and three
methods (`init`, `incr`, `value`). New file `src/image_d2.bas`,
driver `examples/d2_counter.bas`. Proves that messages dispatch
by *receiver class*.

### 3. demo-d3-boolean

Install True/False with `ifTrue:ifFalse:`. New file
`src/image_d3.bas`, driver `examples/d3_boolean.bas`. Proves that
control flow works without native `IF`.

### 4. mini-repl

Optional. A tiny non-general parser that accepts the three demo
grammars from `INPUT`. New file `src/repl.bas`. Skip the step
(or downscope it) if `phase-1-bootstrap` plus D2/D3 already fills
the 16 KB tokenised program area.

### 5. upstream-feature-requests

File one GitHub issue per BASIC v1 limitation in
`sw-cor24-basic`, ordered to enable parallel development. Each
issue links back to the v0 design (`docs/design.md` § 11) and
explains exactly which Smalltalk refactor it unblocks here.

Order (each unblocks a distinct, independently-mergeable refactor
in this repo, so the BASIC agent and this agent can work in
parallel):

1. **FR-2 DATA/READ/RESTORE** — unblocks rewriting `image_d*.bas`
   files (single largest source of repetitive POKE lines).
2. **FR-1 DIM integer arrays** — unblocks rewriting `vm.bas`
   heap/stack/dictionary code (largest source of unreadable
   PEEK/POKE-as-array patterns).
3. **FR-3 ON expr GOTO/GOSUB** — unblocks rewriting the
   bytecode dispatch loop (currently a 14-deep IF-chain).
4. **FR-4 MOD operator** — unblocks cleanup of tag-bit
   extraction.
5. **FR-5 Bitwise AND/OR/XOR/SHL/SHR** — unblocks compact
   tag/format encoding for v1.
6. **FR-6 CONT after STOP** — unblocks an interactive
   single-stepper.

Each issue gets opened as soon as `phase-1-bootstrap` is done.

### 6. refactor-image-data (depends on FR-2 landing upstream)

When `sw-cor24-basic` ships `DATA`/`READ`/`RESTORE`, replace each
`image_d*.bas`'s POKE block with a `DATA` block + a single read
loop. No semantic change.

### 7. refactor-vm-arrays (depends on FR-1 landing upstream)

When `DIM` lands, replace PEEK/POKE-as-heap throughout `vm.bas`
with one or more `DIM` arrays. Heap, eval stack, frame stack,
method dictionary, class table all become real arrays. Bigger
visual cleanup than the runtime change.

### 8. refactor-dispatch-on (depends on FR-3 landing upstream)

When `ON expr GOTO/GOSUB` lands, rewrite the dispatch loop. O(1)
dispatch per opcode and ~40 fewer source lines.

### 9. refactor-mod-and-bits (depends on FR-4 and FR-5 landing)

`MOD` simplifies tag-bit extraction. Bitwise ops let v1 pack the
bytecode pool denser. Small, mergeable cleanup.

### 10. debug-cont-stepper (depends on FR-6 landing upstream)

When `CONT` lands, add a "single-step the VM" mode that `STOP`s
after each bytecode and lets the BASIC user `PRINT P,M,R,S,V`
before resuming. Turns the BASIC REPL into a Smalltalk debugger.

### 11. v0-release-notes

Once D1, D2, D3 all run cleanly, write `README.md` and tag v0.

## Parallel-development contract

This saga's odd-numbered later steps (6-10) all depend on
upstream work in `../sw-cor24-basic`. They are written so they
can be picked up *in any order, as soon as the corresponding FR
lands*. The basic-repo agent does the FRs in the order listed in
step 5; this agent picks up whichever refactor matches whatever
just shipped. No serialisation between agents beyond "FR-N must
be merged before refactor-N can start".
