# Step: demo-d3-boolean

Add demo D3: `5 < 10 ifTrue: [42] ifFalse: [0]` evaluated through
True and False objects with their own `ifTrue:ifFalse:` methods,
proving that control flow in v0 does NOT use a native `IF`.

## Read first
- `docs/design.md` § 5 (bytecode), § 8 (selector id 9 =
  `ifTrue:ifFalse:`), § 11 (Boolean encoding).
- `docs/plan.md` § Phase 9.

## Approach
v0 cheats: `[42]` and `[0]` are method literals, not real
closures. Each `ifTrue:ifFalse:` body just `RETURN_TOP`s the
appropriate literal directly. The receiver's class (True or False)
selects which method runs.

## Deliverables
1. `src/image_d3.bas`: install methods on True (returns arg 0) and
   False (returns arg 1). Install `SmallInteger>><` (primitive 4)
   that pushes True/False ref.
2. `examples/d3_boolean.bas`: driver hand-assembled to evaluate
   `5 < 10 ifTrue: 42 ifFalse: 0`.
3. `scripts/run.sh d3_boolean` prints `42`.

## Definition of done
- D3 prints `42`.
- D1 and D2 still pass.
