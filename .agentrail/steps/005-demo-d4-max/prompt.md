# Step: demo-d4-max

Add demo D4: `5 max: 3 -> 5` via a user-defined method
`SmallInteger>>max:` whose body uses `JUMP_IF_FALSE` to do real
conditional control flow inside Smalltalk bytecode (not the
eager-evaluation cheat D3 used).

## Why this step

D3's `ifTrue:ifFalse:` works only because v0 evaluates both
branches eagerly and the receiver class picks one. That is fine
for constants but doesn't generalise — it would either infinite-
loop on recursive cases or do unwanted work. `JUMP_IF_FALSE` lets
a method skip past a branch entirely. After this step, every
opcode in `docs/design.md` § 5 that's *needed for real Smalltalk
control flow* is implemented and exercised.

## Read first
- `docs/design.md` § 5 (bytecode set, especially OP 10 JUMP and
  OP 11 JUMP_IF_FALSE).
- `src/vm.bas` lines 14000-14130 (the current stubs that return
  `E=1` on JUMP / JUMP_IF_FALSE).

## Deliverables
1. Implement OP 10 `JUMP <off>`: signed 8-bit offset added to P
   *after* the operand byte is consumed.
2. Implement OP 11 `JUMP_IF_FALSE <off>`: pop value V; if V is
   the False singleton (ref 16), apply the offset; otherwise
   advance past it.
3. `src/image_d4.bas`: install
   - `SmallInteger>>< ` (primitive 4) -- carry over from D3
   - `SmallInteger>>max:` (selector id 14):
     ```
     PUSH_TEMP 0     ; n
     PUSH_SELF       ; self
     SEND <,1        ; n < self -> True/False
     JUMP_IF_FALSE 2 ; if false (i.e. n >= self), skip 2 bytes
     PUSH_SELF
     RETURN_TOP
     PUSH_TEMP 0
     RETURN_TOP
     ```
4. `examples/d4_max.bas`: top-level driver that hand-assembles
   `5 max: 3` (PUSH_INT 5; PUSH_INT 3; SEND 14,1; PRIM 5; HALT)
   and runs it.
5. `scripts/run.sh d4_max` prints `5`.

## Definition of done
- D4 prints `5`.
- D1, D2, D3 all still pass (regression).
- `docs/status.md` updated; `docs/design.md` § 11 doesn't change
  (no new BASIC FRs needed).
