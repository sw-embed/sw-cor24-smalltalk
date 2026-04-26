# Step: demo-d7-bounded-counter

Add inheritance to the v0 VM and demonstrate it via D7:
`BoundedCounter` is a subclass of `Counter` that overrides `incr`
to cap at 5. After 6 `incr` calls starting from 0, `value` should
be `5` (not `6`), proving:

1. The receiver's *own* class wins on dispatch (incr resolves to
   BoundedCounter>>incr, not Counter>>incr).
2. Methods missing from the receiver class are looked up on the
   superclass (init and value resolve to Counter>>init and
   Counter>>value via the chain walk).

## VM changes

1. **Superclass table** at scratch addresses 752..767 (16 slots,
   currently labelled "reserved" in `docs/architecture.md` § 3).
   `PEEK(752+i)` is the superclass id of class `i`. Walking ends
   when the value goes negative.
2. **INSTALL_SINGLETONS** sets `class_super[0] = -1` so the chain
   terminates at Object. Built-in classes 1..9 default to
   superclass 0 (Object) since `um[]` starts at zero.
3. **LOOKUP** in `src/vm.bas`: on a method-dictionary miss, walk
   `C := class_super[C]` and retry. Stop when `C < 0`. Also: fix
   the long-standing bug where the no-match path wrote `T = -1`
   instead of `Q = -1` (latent because D1-D6 never miss).

## Image changes

`src/image_d7.bas` installs:

- `SmallInteger>>+` (primitive 1) and `SmallInteger>><`
  (primitive 4) -- needed by BoundedCounter>>incr.
- `Counter>>init` (PUSH_INT 0; STORE_FIELD 0; PUSH_SELF;
  RETURN_TOP) on class 10.
- `Counter>>value` (PUSH_FIELD 0; RETURN_TOP) on class 10.
- `BoundedCounter>>incr` on class 11, body uses JUMP_IF_FALSE to
  skip the increment when value >= 5:

  ```
  PUSH_FIELD 0
  PUSH_INT 5
  SEND <,1                  ; value < 5 ?
  JUMP_IF_FALSE +11         ; if not, skip the body
  PUSH_FIELD 0
  PUSH_INT 1
  SEND +,1
  STORE_FIELD 0
  PUSH_SELF
  RETURN_TOP
  PUSH_SELF                 ; cap reached: just return self
  RETURN_TOP
  ```

- `class_super[11] = 10` (BoundedCounter inherits from Counter).
  `class_super[10]` defaults to 0, so Counter inherits from
  Object.

## Driver

`examples/d7_bounded.bas`:

- Allocate a BoundedCounter (class 11, 1 instance variable) via
  direct GOSUB to ALLOC.
- Top-level bytecode (27 bytes): `SEND init,0; SEND incr,0 (x6);
  SEND value,0; PRIM 5; HALT`.
- Run, expect `5` printed.

## Definition of done

- D7 prints `5`.
- D1-D6 all still pass.
- The init/value methods on Counter are *only* present on class
  10, never installed on class 11. (Verifies inheritance walk
  actually fires.)
- Update README and status.
