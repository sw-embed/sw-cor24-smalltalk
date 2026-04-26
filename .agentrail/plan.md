# Saga: v1.x-demos

After v1.0 shipped strings + Transcript, this saga ports the
demo backlog and rewrites D5 calc to use the new text I/O.

Issues closed:
- `sw-cor24-smalltalk#3` — guess demo
- `sw-cor24-smalltalk#1` — partial (fib, gcd, linked-list)

## Steps

1. `compiler-allow-value-stmts-in-methods` — extend stc.awk so
   method bodies can contain bare value statements (e.g.
   `Transcript show: 'x'.`), POP'd unless followed by `^`.
2. `demo-guess` — port from `../sw-cor24-basic/examples/guess.bas`.
   BASIC driver loops; Smalltalk methods print "higher" /
   "lower" / "got it in N guesses" via Transcript.
3. `demo-fibonacci` — `examples/fibonacci.st`. `7 fib` -> 13
   with friendly text output.
4. `demo-gcd` — `examples/gcd.st`. `12 gcd: 18` -> 6.
5. `demo-linked-list` — `Cell` class with `head` + `tail`,
   `Cell>>sum` walks the chain.
6. `d5-rewrite` — D5 calc prints `A op B = C` instead of bare C.
7. `v1.x-release-notes` — tag `v1.1.0`, push.
