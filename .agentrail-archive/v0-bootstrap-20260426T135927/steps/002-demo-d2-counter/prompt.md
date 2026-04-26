# Step: demo-d2-counter

Add demo D2: a user-defined `Counter` class with one instance
variable (`value`) and three methods (`init`, `incr`, `value`).
After running `c init incr incr value print` the program should
print `2`.

## Read first
- `docs/design.md` § 5 (bytecode set), § 6 (method dictionary),
  § 7 (SEND/activation), § 8 (selector ids 6/7/8 reserved for
  init/incr/value).

## Deliverables
1. `src/image_d2.bas`: install class id 10 (Counter, instvar count
   1, super = Object). Install three methods at the byte addresses
   reserved in `docs/design.md` § 5.1.
2. `examples/d2_counter.bas`: driver that allocates a Counter (via
   primitive 6 `new` if implemented, else by direct ALLOC), sends
   `init`, `incr`, `incr`, `value`, prints the result.
3. Add primitive 6 (`new`) to `src/vm.bas` if not already there
   from phase-1.
4. `scripts/run.sh d2_counter` prints `2`.

## Definition of done
- D2 prints `2`.
- D1 still passes (regression check).
- New code review-able under 200 lines including comments.
