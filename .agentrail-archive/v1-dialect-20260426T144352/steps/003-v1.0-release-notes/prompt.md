# Step: v1.0-release-notes

Tag `v1.0.0` and update README.

The minimum viable v1 surface (`sw-cor24-smalltalk#4`) shipped
in step 002.  This step ships the version tag.

## Out of scope (defer to a v1.x saga)

- D5 calc rewrite to use strings (`A op B = C` formatting)
- guess demo (issue #3)
- Demo backlog (fib, gcd, linked-list — issue #1)
- `String>>length`, `>>at:`, `>>,` (concat)
- Cascades (`a; b; c`)

These are good follow-ups but none blocks the web agent now
that hello.st works.

## Deliverables

1. README updated: dialect note "v1 ships String + Transcript",
   add hello.st to the demo table.
2. `docs/status.md` decision log entry: v1.0.0 tagged.
3. Tag `v1.0.0` annotated with the diff vs v0.1.0 (one major
   addition: v1 strings + Transcript pipeline).
4. Push tag.

## Definition of done

- Tag `v1.0.0` exists locally and on origin.
- README and status reflect the v1 milestone.
- Saga `v1-dialect` complete.
