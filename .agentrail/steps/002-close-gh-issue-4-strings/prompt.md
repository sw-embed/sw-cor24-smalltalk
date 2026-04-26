# Step: close-gh-issue-4-strings

**Top priority.** Minimum implementation that closes
[`sw-cor24-smalltalk#4`](https://github.com/sw-embed/sw-cor24-smalltalk/issues/4)
and unblocks the web agent.

Skip every nice-to-have. Just enough to ship a hello-world
demo and `Transcript show: ... printString` so demos can emit
human-readable text.

## Minimum surface (defer everything else to subsequent steps)

In `src/vm.bas`:

1. `DIM T(15)` literal-pool array (16 slots).
2. New bytecode `PUSH_LIT n` (opcode 2) reads `T(n)` and pushes.
3. String heap layout per spec (byte-per-word).
4. Class id 12 = String.
5. Heap-resident `Transcript` singleton at heap addr 12 (was
   empty-Array placeholder, repurpose).
6. Primitive 7 `Transcript show:` — pop arg, walk bytes, putc
   each, leave receiver on stack.
7. Primitive 8 `Transcript cr` — putc 10, leave receiver.
8. Primitive 9 `SmallInteger>>printString` — decode, decimal-
   format into fresh heap String, push tagged ref.

In `tools/stc.awk`:

9. Tokenise `'string'` literals (no escape rules, no embedded
   quotes for now). Each unique literal string allocates next
   pool slot.
10. Emit literal records in DATA at `lit-class-id-marker = -2`
    sentinel (or a new sentinel) so `read_and_install_methods`
    can distinguish from regular methods.
11. Update `read_and_install_methods` (or write a new
    `read_and_install_with_literals`) to: when sees `class=-2`
    record, ALLOC heap String, store tagged ref in `T(slot)`.
    When sees regular method record, install as before.
12. Emit `PUSH_LIT n` for each `'string'` token.
13. Resolve `Transcript`, `printString`, `show:`, `cr` in
    selector / class tables.

In `examples/`:

14. New `examples/hello.st`:
    ```
    main
      Transcript show: 'hello, world'.
      Transcript cr
    end
    ```

## Definition of done

- `./scripts/run-st.sh examples/hello.st` outputs:
  ```
  hello, world
  ```
- D1..D8 still pass (no regression).
- File a comment on issue #4 with a link to the commit and the
  hello-world demo. Close the issue.

## Out of scope (DEFERRED to v1 finishing steps after this)

- `String>>length` / `>>at:` / `>>,`
- Cascades (`a; b; c`) — for now `Transcript show: 'x'.
  Transcript cr` is two statements
- D5 calc rewrite to use strings (separate step)
- guess demo (separate step)
- demo backlog (fib/gcd/list)
- v1.0.0 release tag (separate step)

This step is INTENTIONALLY scoped tight. Ship the minimum.
Refinement steps follow.
