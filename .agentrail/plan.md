# Saga: v1-dialect

Tinytalk dialect upgrade from v0 (integer-only Smalltalk) to v1
(strings + literal pool + Transcript primitive). Anchored on
[`sw-cor24-smalltalk#4`](https://github.com/sw-embed/sw-cor24-smalltalk/issues/4)
which is the web agent's primary blocker as of v0.1 ship.

## Goal

Demos should print readable text instead of bare integers. The
canonical motivating example is rewriting D5 calc so user sees:

```
> 3 + 4
3 + 4 = 7
> _
```

instead of today's `7`. Equally important: `Transcript show:
'hello, world'. Transcript cr.` becomes the smallest possible
`hello world` in the dialect, and the deferred `guess` demo
(issue #3) becomes feasible.

## Scope

### v1 dialect features (issue #4)

- **String / Symbol class** — heap-resident, length-prefixed
  byte sequence. Symbols are interned + immutable; Strings can
  start mutable (concat) but immutable for v1 keeps the runtime
  simple.
- **Literal pool** — per-image table of literal references
  (Symbols, Strings, possibly later Arrays). New bytecode
  `PUSH_LIT n` reads from the pool; the v0-reserved opcode 2
  finally has a meaning.
- **`Transcript show:` / `cr`** — primitives that write a String
  / byte to UART (i.e., to BASIC's `PRINT`/`writechar`).
- **`SmallInteger>>printString`** — converts a SmallInt to a
  String (as a heap object), so `Transcript show: x printString`
  works.

### v1 compiler features (extends issue #5)

- Tokenize string literals `'...'`, hand them to the literal
  pool, emit `PUSH_LIT n`.
- Parse `Transcript show: 'hi'. Transcript cr.` keyword sends.
  (The compiler already handles keyword sends in main; needs to
  handle them inside method bodies too.)
- Add `;` cascades — first cascade demo lands here.

### Demos that ship in v1

- D5 calc rewrite: `3 + 4 = 7` text output.
- guess game (issue #3): "higher" / "lower" / "got it in N
  guesses" — the canonical "first interactive game".
- Backlog from issue #1 — fib / gcd / linked-list authored as
  proper Smalltalk-with-strings demos: `fib(7) = 13`.

## Steps

### 1. dialect-v1-spec

Design doc: Symbol vs String split (or unified), heap layout,
literal pool format, new bytecodes, primitive numbers for
Transcript / printString. Update `docs/design.md` and
`docs/st-source.md` with the v1 grammar diff.

### 2. dialect-v1-vm-strings

`src/vm.bas`: add String class (id 12 say) heap layout, ALLOC
helper for byte arrays, `String>>length` / `>>at:` / `>>,`
primitives, `SmallInteger>>printString` primitive. Generalize
PUSH_LIT (opcode 2) to fetch from the literal pool.

### 3. dialect-v1-vm-transcript

`Transcript show:` / `cr` primitives that pump bytes to the
sibling BASIC's PRINT/writechar.

### 4. dialect-v1-image-format

Extend the FR-2 DATA stream so the image carries a literal
pool: each Symbol/String literal is its own DATA record with
a discriminator. `read_and_install_methods` becomes
`read_and_install` (handles both methods and literals).

### 5. dialect-v1-compiler

`tools/stc.awk` extensions: `'string'` literal tokenization,
literal pool emission in DATA, `PUSH_LIT n` emission, method-
body keyword sends, cascades.

### 6. dialect-v1-hello-world

Smallest possible v1 demo: `Transcript show: 'hello, world'.
Transcript cr.` Round-trips through the compiler and runs.

### 7. dialect-v1-d5-rewrite

D5 calc rewritten to print `A op B = C` instead of bare `C`.
Includes `SmallInteger>>printString` if not already in step 2.

### 8. dialect-v1-guess-demo

`examples/guess.st` — port from
`../sw-cor24-basic/examples/guess.bas`. Closes
[`sw-cor24-smalltalk#3`](https://github.com/sw-embed/sw-cor24-smalltalk/issues/3).

### 9. dialect-v1-demo-backlog

Three v0-feasible demos from issue #1 reauthored with strings:
fibonacci, gcd, linked-list. Output: `fib(7) = 13`,
`gcd(12, 18) = 6`, `Cell sum = 15`.

### 10. dialect-v1-release-notes

Update README, status, design.md. Tag `v1.0.0`. Close
[`sw-cor24-smalltalk#4`](https://github.com/sw-embed/sw-cor24-smalltalk/issues/4).

## Out of scope (v2+)

- Block literals (`[ :a | body ]`) and lazy evaluation — issue #2
  v2 dialect.
- Arrays (`Array new: 10`) — issue #2 v3 dialect.
- doesNotUnderstand: handler — issue #2 v5.
- Exceptions — issue #2 v6.
- Process scheduler — issue #2 v7.
- Self-hosted compiler.

These belong to subsequent dialect upgrade sagas.
