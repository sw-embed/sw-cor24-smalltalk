# Step: refactor-dispatch-on (depends on FR-3 in sw-cor24-basic)

**BLOCKED until** `sw-cor24-basic` issue [FR-3] ON expr GOTO/GOSUB
ships.

## Goal

Rewrite the bytecode dispatch loop in `src/vm.bas` (lines
2000-2099 today, an `IF`-chain) to use `ON OP+1 GOSUB
3000,3100,...`. O(1) dispatch instead of O(n).

Also rewrite the primitive trampoline (PRIMITIVE handler) to use
`ON N GOSUB 4500,4520,...`.

## Verification
- D1, D2, D3 still produce 7, 2, 42.
- The dispatch loop fits on one screen.
- `examples/smoke/gosub_chain.bas` is rerun for comparison; record
  the speed-up in `docs/status.md`.

## Update docs
- `docs/architecture.md` § 5: replace the IF-chain sketch with the
  `ON GOSUB` form.
- `docs/design.md` § 11.1 #3: mark resolved.
