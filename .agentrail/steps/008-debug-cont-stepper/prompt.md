# Step: debug-cont-stepper (depends on FR-6 in sw-cor24-basic)

**BLOCKED until** `sw-cor24-basic` issue [FR-6] CONT after STOP
ships.

## Goal

Add a "single-step the VM" mode to `src/vm.bas`. When enabled:
- The dispatch loop `STOP`s after each opcode.
- BASIC variables `P,M,R,S,V,O` remain readable from the BASIC
  REPL.
- Typing `CONT` resumes one more opcode.
- Typing `RUN` from inside the demo restarts.

Toggle via a flag word in the heap (e.g. addr 1007 = step mode).

## Verification
- A new demo `examples/d_step.bas` runs D1 with step mode on and
  shows registers between bytecodes.
- D1, D2, D3 still produce 7, 2, 42 with step mode off.

## Update docs
- `docs/design.md` § 11.1 #7: mark resolved.
- `docs/status.md`: declare a Smalltalk debugger feature available.
