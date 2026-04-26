# Step: v0.1-release-notes

Final step of the `v0-bootstrap` saga. Run AFTER all five
refactor steps and the CONT stepper feature have landed.

## Goals

1. Update `README.md` to reflect that the BASIC FRs have been
   dogfooded. Replace the "Six upstream feature requests are filed
   against `sw-cor24-basic`..." table with a "Built on BASIC v1.x
   features..." paragraph that lists which FR each VM piece uses.
2. Update `docs/status.md` to declare v0.1 done. Replace the
   "Saga state at tag" sentence in the `minimal-basic-with-workarounds`
   tag with one that points to the new tag.
3. Update `docs/design.md` § 11 to mark FR-1..FR-6 all resolved
   (currently they're "Blocking-or-painful" with workarounds
   listed). Move the section to a "Resolved upstream" subsection.
4. Confirm all 7 demos (D1-D7) plus any new demos still pass.
5. `git tag -a v0.1.0`. The annotation should explicitly
   contrast against the `minimal-basic-with-workarounds` tag,
   listing what changed: every workaround removed, BASIC features
   used, line count diff in vm.bas, etc.
6. Push tags.

## Definition of done

- v0.1.0 tagged and pushed.
- `git diff minimal-basic-with-workarounds..v0.1.0 -- src/` is
  the canonical "what dogfooding the FRs looked like" record;
  it should be visibly cleaner code, not just shorter.
- README's "Status" section says v0.1 is current.
- Saga `v0-bootstrap` complete (`agentrail complete --done`).

## Notes

This is documentation + tag, no new code. If during the
refactor steps you discover that something doesn't actually
fit any FR neatly, document it here as a v0.2 candidate — do
not invent new BASIC features in this step.
