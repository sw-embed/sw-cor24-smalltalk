# Step: compiler-allow-value-stmts-in-methods

Today `stc.awk` only accepts bare value statements inside `main`
blocks; method bodies require `^`, `:=`, `if`, or `primitive`.
Extend it so method bodies can also contain value statements
(e.g., `Transcript show: 'x'.`), each POP'd to discard the
result before the next statement runs.

## Change

In the catch-all pattern, drop the `in_main` gate; always
compile as a value statement (POP after).

## Definition of done

- A method body like:
  ```
  method tellHigher
    Transcript show: 'higher'.
    Transcript cr.
    ^ self
  ```
  compiles cleanly. The two value statements get POP'd; the
  trailing `^ self` returns self.
- D1..D8 + hello.st all regress-pass.
