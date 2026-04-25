# Step: refactor-vm-arrays (depends on FR-1 in sw-cor24-basic)

**BLOCKED until** `sw-cor24-basic` issue [FR-1] DIM integer arrays
ships.

## Goal

Replace PEEK/POKE-as-array idioms throughout `src/vm.bas` with
real `DIM`med integer arrays. Heap, eval stack, frame stack,
method dictionary, class table, symbol table all become arrays.

The address layout in `docs/architecture.md` § 3 stays the same
*conceptually* — the arrays are just more readable than indexing
into a 1024-word PEEK/POKE region.

## Verification
- D1, D2, D3 still produce 7, 2, 42.
- `vm.bas` is at least 20% shorter.
- No remaining `PEEK(`/`POKE ` calls in `vm.bas` (smoke tests
  in `examples/smoke/` still use them — those stay).

## Update docs
- `docs/architecture.md` § 3: note that the v0.1 implementation
  uses `DIM` arrays internally; the conceptual address layout is
  retained for the educational diagram.
- `docs/design.md` § 11.1 #1: mark resolved.
