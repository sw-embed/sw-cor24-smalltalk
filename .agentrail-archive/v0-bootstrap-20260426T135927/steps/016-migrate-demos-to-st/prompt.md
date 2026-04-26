# Step: migrate-demos-to-st

After step 015 ships the `.st` compiler proving the round-trip
on D2, migrate the other six demos so every one has a `.st`
source. Hand-written `image_d*.bas` files become a fallback
for demos whose syntax `stc` can't yet express, but the bar is:
the source for any demo should fit in a `.st` file readable as
Smalltalk.

## Per-demo migration

| Demo | Equivalent Smalltalk |
|---|---|
| D1 | `(3 + 4) print` (top-level expression) |
| D3 | `(5 < 10) ifTrue: 42 ifFalse: 0` |
| D4 | `SmallInteger>>max: n` user method using `JUMP_IF_FALSE` for the conditional |
| D5 | the calc-REPL driver - top-level only |
| D6 | `SmallInteger>>fact` recursive method |
| D7 | `Counter`/`BoundedCounter` with subclass-of declaration; superclass walk happens at run time |

Some of these (D4, D6) need conditional control flow inside a
method; the compiler may need to recognise an `ifTrue:ifFalse:`
form and lower it to `JUMP_IF_FALSE` rather than a real send (the
"D3 cheat" works only when the receiver is True or False).

D7 needs subclass declarations: `class BoundedCounter extends
Counter [ ... ]`. The compiler emits the right `class_super[]`
slot.

## Deliverables

1. `examples/d1_add.st`, `d3_boolean.st`, `d4_max.st`,
   `d5_calc.st`, `d6_fact.st`, `d7_bounded.st`.
2. Compiler updates as needed to handle the new syntactic
   shapes. Each new feature documented in `docs/st-source.md`.
3. `src/image_d{1,3,4,5,6,7}.bas` deleted from the repo
   (they are now generated). `.gitignore` covers
   `build/image_*.bas`.
4. All seven demos still print their expected outputs.

## Definition of done

- `examples/*.st` is the only place Smalltalk method bodies
  exist as text in the repo. The hand-written `image_d*.bas`
  files are gone.
- Running any demo invokes `stc` from `scripts/build.sh` to
  regenerate the image as a build artifact.
- `docs/st-source.md` covers every syntactic feature used by
  any of the seven demos.
- The seven demos produce identical outputs to before
  migration (7, 2, 42, 5, REPL transcript, 120, 5).
