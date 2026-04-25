# Step: demo-d6-fact

Add demo D6: `5 fact -> 120` via a real recursive
`SmallInteger>>fact`. This is the project's first proof that the
frame stack handles recursion depth > 2; D2's `Counter>>incr`
nests one level deep (incr -> +), but every fact call adds another
frame.

## Why this step

D4 introduced `JUMP_IF_FALSE` for in-method conditionals, but it
didn't recurse. D2 introduced user methods, but the call graph is
always shallow. D6 puts both together: the method calls itself,
and only the `JUMP_IF_FALSE` branch path saves us from infinite
recursion (the `ifTrue:ifFalse:` cheat from D3 would evaluate
`(self - 1) fact` even at the base case, which loops forever
since blocks are eager in v0).

## Read first
- `docs/design.md` § 5 (bytecodes), § 7 (frame format),
  § 9 (primitives).
- `src/image_d4.bas` for the JUMP_IF_FALSE pattern.

## Method body

Notional source:

```
SmallInteger>>fact
  ^(0 < self)
     ifFalse: [1]
     ifTrue:  [self * (self - 1) fact]
```

But hand-compiled to bytecode using JUMP_IF_FALSE (same trick as
D4). Selector id `fact` = 15.

```
ofs  bytes      meaning
 0   12 0       PUSH_INT 0
 2   1          PUSH_SELF
 3   7  4 1     SEND <,1
 6   11 14      JUMP_IF_FALSE +14   -> base case at ofs 22
 8   1          PUSH_SELF
 9   1          PUSH_SELF
10   12 1       PUSH_INT 1
12   7  2 1     SEND -,1
15   7 15 0     SEND fact,0          recursive call
18   7  3 1     SEND *,1
21   8          RETURN_TOP
22   12 1       PUSH_INT 1           base case starts here
24   8          RETURN_TOP
```

Total: 25 bytes.

## Deliverables

1. `src/image_d6.bas` installs five SmallInteger methods at the
   bytecode pool: `+` (prim 1), `-` (prim 2), `*` (prim 3),
   `<` (prim 4), and `fact` (the user method above).
   Selector id 15 = fact.
2. `examples/d6_fact.bas` hand-assembles the top-level bytecode
   `PUSH_INT 5; SEND fact,0; PRIM 5; HALT` at scratch addr 600
   and runs it.
3. `scripts/build.sh` wires up `d6_fact`.
4. `scripts/run.sh d6_fact` prints `120` (= 5!).

## Definition of done

- D6 prints `120`.
- D1-D5 all still pass.
- README and status updated.
- No new BASIC FRs needed (every required opcode is already
  implemented).
