# Step: refactor-image-data (depends on FR-2 in sw-cor24-basic)

**BLOCKED until** `sw-cor24-basic` issue [FR-2] DATA/READ/RESTORE
ships and the sibling `scripts/build-basic.sh` produces a working
interpreter that supports it.

## Goal

Replace the explicit `POKE addr,val` blocks in `src/image_d1.bas`,
`src/image_d2.bas`, `src/image_d3.bas` with `DATA` blocks read by
a single small `READ` loop. No semantic change; the demos must
produce identical output.

## Verification
- D1, D2, D3 still produce 7, 2, 42.
- Each `image_d*.bas` is at least 30% shorter and noticeably more
  readable.
- The DATA block layout is documented at the top of `vm.bas`.

## Notes for the agent

This step is the cleanest "first parallel refactor" because it
touches only image files, never the VM core. Do not rewrite
`vm.bas` heap code in this step — that is a separate refactor
gated on FR-1 (DIM).
