# Step: demo-backlog-v0-fib-gcd-list

Land a curated subset of `sw-cor24-smalltalk#1` (Demo backlog) as
`.st` files. Run AFTER `016-migrate-demos-to-st` so the compiler
exists and each new demo is roughly 10 lines of source instead
of 30-60 lines of hand-assembled BASIC.

The full backlog (issue #1) lists 10 candidates. This step lands
just three, picked for pedagogical breadth:

| Demo | Why include | Smalltalk shape |
|---|---|---|
| **fibonacci** | recursion with TWO recursive calls per frame, complementing D6's single-recursion `fact` | `SmallInteger>>fib  ^ self < 2 ifTrue: [self] ifFalse: [(self - 1) fib + (self - 2) fib]` |
| **gcd** | first two-argument recursive method | `Integer>>gcd: n  ^ n = 0 ifTrue: [self] ifFalse: [n gcd: (self mod: n)]` |
| **linked-list** | first multi-object user heap (Cell with head + tail), exercises ALLOC + STORE_FIELD across multiple instances | `Cell` with `head`/`tail` instance vars; `Cell>>sum` walks via tail recursion |

The remaining seven (power, prime, ackermann, hanoi, stack/queue,
state-machine, compare-mixin) stay open in issue #1 for v0.2
or whichever saga picks them up.

## Constraints

- Each demo must be expressible in the `.st` syntax landed by
  step 015 + extensions from step 016. If a demo needs syntax
  the compiler doesn't yet support, document the gap and move on
  rather than expanding the compiler in this step.
- Print a single SmallInteger as the result (matches D1..D7
  output style; no strings yet — that's the v1 dialect work).

## Deliverables

1. `examples/d_fib.st`, `examples/d_gcd.st`, `examples/d_list.st`
   (or whatever naming convention the migrated demos settled on
   in step 016).
2. Companion drivers under `examples/` if needed for top-level
   expressions.
3. `scripts/build.sh` recognises the new demo names.
4. Each demo's expected output:
   - `7 fib -> 13`
   - `12 gcd: 18 -> 6`
   - `(Cell with 1, 2, 3, 4, 5) sum -> 15`
5. README's demo table extended with three more rows.

## Definition of done

- All ten v0 demos (D1..D7 plus the new three) print their
  expected outputs.
- The `.st` source for each new demo fits in roughly 10 lines.
- Issue #1's checklist updated (mark fib/gcd/linked-list done;
  link the commit). `gh issue comment 1` from the saga step's
  commit.
