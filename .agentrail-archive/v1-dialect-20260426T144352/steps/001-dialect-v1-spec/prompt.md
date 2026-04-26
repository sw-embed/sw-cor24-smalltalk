# Step: dialect-v1-spec

Design doc + minimum-viable string semantics. Update
`docs/design.md` and `docs/st-source.md` with:

- String heap layout (header + length-prefixed bytes).
  Recommendation: `H(addr+0)=class-id-12, H(addr+1)=byte-length,
  H(addr+2)=format=1 (byte storage), H(addr+3..)=raw bytes
  packed one byte per heap word`. Wastes space but lets
  existing `H()` array hold strings without a separate byte
  heap.
- Symbol vs String for v1: unified as String. Symbols (interned)
  arrive in v2 if needed. v1 strings are immutable in usage
  but the runtime doesn't enforce it.
- Literal pool: a separate region in the bytecode pool? Or its
  own slot? Recommend a per-image table at scratch addresses
  768..831 (16 entries x 4 words: type, addr_hi, addr_lo, ...).
  Or simpler: literals are heap-resident, the literal-pool table
  is just an array of tagged refs.
- New bytecode operands: `PUSH_LIT n` (opcode 2) reads from
  literal table at index n.
- Primitives: 7 = `Transcript show:` (pop tagged ref to String,
  walk bytes, putc each), 8 = `Transcript cr` (writechar 10),
  9 = `SmallInteger>>printString` (decimal-encode an int into
  a fresh String, push tagged ref).
- Selector additions: `show:` (id 16), `cr` (id 17),
  `printString` (id 18), `,` (id 19) for concat.

## Decision: byte-per-word vs packed bytes

Byte-per-word: `H(addr+3)=byte0, H(addr+4)=byte1, ...`. Wastes
3 bytes per string char (BASIC integers are 24-bit) but trivial
to read/write. Strings of 64 chars use 64 heap words.

Packed: 4 bytes per word, `H(addr+3)=byte0|byte1|byte2|byte3`,
extract via `(H(addr+3) SHR 16) BAND 255`, etc. Saves space
but adds `BAND` / `SHR` per character read. With 512-word heap,
strings of length up to ~32 chars (byte-per-word) or ~128
(packed). v1 demos won't push past 100 chars, so byte-per-word
is fine.

**Decision: byte-per-word.** Document the trade-off in
`docs/design.md`.

## Deliverables

1. `docs/design.md` — new "v1 dialect" section covering
   String, literal pool, new opcodes, primitives, and the
   byte-per-word storage rationale.
2. `docs/st-source.md` — v1 grammar additions: string literals
   `'...'`, cascades `;`, method-body keyword sends.
3. `docs/status.md` — v1-dialect saga active note.

No code changes in this step — just design.

## Definition of done

- Design doc captures every decision needed for steps 2-9.
- An agent picking up step 2 (vm-strings) has a clear spec to
  implement against.
