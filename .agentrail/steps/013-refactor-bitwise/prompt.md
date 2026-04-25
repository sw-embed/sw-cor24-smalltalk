# Step: refactor-bitwise

Replace the four tag/heap arithmetic helpers in `src/vm.bas` with
the bitwise operators that landed in `sw-cor24-basic` via FR-5
(BAND/BOR/BXOR/SHL/SHR, shipped in commit `8ab3654` on the
sibling repo's `main`). FR-5 is closed (issue #6).

This step is the FR-5 half of what was originally the combined
`refactor-mod-and-bits` step. The FR-4 (MOD) half stays in step
`refactor-mod-and-bits`; this one focuses solely on bitwise ops.

## Read first

- `../sw-cor24-basic/CHANGELOG.md` and the `feat(basic): FR-5 …`
  commit, to confirm the operator names and precedence the BASIC
  parser actually accepts.
- `src/vm.bas` lines 9100, 9200, 9300, 9400 — the four helpers
  this step rewrites.
- `docs/design.md` § 2.1 — the documented teaching version of the
  helpers (currently shows arithmetic; update this section to
  show both the arithmetic and bitwise forms, since this VM
  remains a teaching artefact).

## Helpers to rewrite

| Helper | Today (workaround) | After (dogfood) |
|---|---|---|
| `ISINT` (line 9110) | `T = V - (V/2)*2` | leave as MOD form (handled by FR-4 step), or use `T = V BAND 1` if FR-4 step hasn't run yet |
| `TOINT` (line 9210) | `T = (V-1)/2` | `T = V SHR 1` (low bit was 1 for SmallInts; shifting right discards it) |
| `MKINT` (line 9310) | `T = V*2 + 1` | `T = (V SHL 1) BOR 1` |
| `PADDR` (line 9410) | `T = V/2` | `T = V SHR 1` |

`ISINT` only stays in this step if the MOD step (FR-4 work,
sibling step `refactor-mod`) has not run yet. If FR-4 already
landed in vm.bas as `T = V MOD 2`, leave it alone — pick
whichever form is cleaner once both FRs are dogfooded.

## Verification

- All seven demos (D1-D7) produce identical output.
- `git diff` should touch only the four helpers (and the docs).
- Run a smoke test confirming a few specific cases:
  - `MKINT(0) = 1` (tagged SmallInt 0).
  - `MKINT(7) = 15`.
  - `TOINT(15) = 7`.
  - `PADDR(8) = 4` (true singleton ref → heap addr).
  These should already match the existing arithmetic forms but
  are worth pinning explicitly since shift semantics on a
  signed 24-bit value can surprise (especially `SHR` on a
  negative number — the v0 demos never exercise that, but the
  smoke test should record what does happen).

## Definition of done

- D1-D7 regression-pass.
- `src/vm.bas` shows bitwise ops at the four helper sites.
- `docs/design.md` § 2.1 mentions both forms.
- Status doc updated (mark FR-5 resolved in § 11 of design.md).
