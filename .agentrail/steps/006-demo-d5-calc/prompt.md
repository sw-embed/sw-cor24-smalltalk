# Step: demo-d5-calc

Build a tiny interactive REPL that reads integers from `INPUT`,
runs the corresponding Smalltalk send through the v0 VM, prints
the result, and loops. This is the project's first interactive
surface.

## Constraint and approach

BASIC v1 has no string variables, so a true source-text REPL
(parsing `3 + 4`) is impossible without modifying the host.
Instead, prompt for three integers per iteration: `a`, `op`,
`b`. Each tuple becomes the bytecode `PUSH_INT a; PUSH_INT b;
SEND op,1; PRIMITIVE 5 (print); HALT` and runs through the same
dispatch loop the four scripted demos use.

`op` is an integer selector id directly. Selector ids in v0:
1 = `+`, 2 = `-`, 3 = `*`, 4 = `<`, 14 = `max:`. `op = 0` exits.

## Deliverables

1. `src/image_d5.bas` installs all five SmallInteger methods at
   bytecode pool offsets 512+ (four primitives, one user method
   carried over from D4).
2. `examples/d5_calc.bas` is the REPL driver: prompt loop,
   integer reads, in-place bytecode patching at scratch addr
   540, dispatch invocation, result print (via `PRIMITIVE 5`),
   reset E/S/F per iteration, `END` on `op = 0`.
3. `scripts/build.sh` wires up the `d5_calc` case.
4. A test transcript proving multiple operations work in one
   session, with at least:
   - `5 + 3` -> 8
   - `7 - 2` -> 5
   - `4 * 6` -> 24
   - `2 < 3` -> 8 (the True singleton ref; documented behaviour)
   - `5 max: 3` -> 5
   - exit on `op = 0`

## Definition of done

- `scripts/run.sh d5_calc < transcript.in` produces the expected
  output for the five operations above.
- D1-D4 all still pass.
- README updated with a fifth row describing the REPL.

## Notes for the agent

- The BASIC interpreter's `INPUT` reads from stdin. A test
  transcript is just `cat << EOF` of the per-iteration values
  plus a trailing `0` to quit and `BYE` to exit BASIC. Wire one
  up under `tests/d5_calc.in` so the demo is reproducible.
- `< ` returns 8 (True singleton ref) or 16 (False) rather than
  a SmallInt, so PRIMITIVE 5 will refuse to print it (that
  primitive errors on non-SmallInt input). Either accept the
  asymmetry and document it, or add a tiny print helper that
  recognises the booleans. Pick the simpler path; this is a
  demo not a polished UX.
