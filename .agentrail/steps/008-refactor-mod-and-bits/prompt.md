# Step: refactor-mod-and-bits (depends on FR-4 + FR-5)

**BLOCKED until** `sw-cor24-basic` issues [FR-4] MOD and [FR-5]
bitwise operators both ship. May proceed if only one of the two
ships, doing only the corresponding cleanup half.

## Goal

- Replace `V - (V/2)*2` tag-bit extraction in
  `src/vm.bas` (lines 1010-ish) with `V MOD 2`.
- Replace any `*2` / `/2` tag operations with `SHL 1` / `SHR 1` if
  bitwise ops shipped.

## Verification
- D1, D2, D3 still produce 7, 2, 42.
- `vm.bas` line count drops slightly.

## Update docs
- `docs/design.md` § 11.1 #4 and #5: mark resolved.
