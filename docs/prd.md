# COR24 Smalltalk v0 — Product Requirements Document

## 1. Problem Statement

The COR24 ecosystem has Pascal (compiled, structured) and BASIC v1
(interpreted, dynamic, hardware-oriented). It does not have a
*message-passing object* language. We want a minimal, integer-only
"Tinytalk" — small enough to demonstrate the Smalltalk execution
model (objects, classes, message sends, late binding, bytecode
dispatch) on the COR24 substrate without committing to a full
Smalltalk-80 implementation.

The chosen vehicle is the existing COR24 BASIC v1 interpreter,
hosting a tiny Smalltalk *VM* whose state lives entirely in BASIC's
PEEK/POKE scratch memory and 26 scalar variables. BASIC is the
"microcode" the way the Alto microcode hosted Smalltalk-76 — slow,
visible, teachable. That is the point.

## 2. Target Users

- COR24 ecosystem users who want a third dialect alongside Pascal
  and BASIC, demonstrating object-oriented execution on the same
  p-code VM.
- Educators and learners exploring the message-send model. The
  whole VM should fit on a few printed pages and be steppable in a
  debugger.
- Future authors of a visual ("tile / tree") composer that emits
  the same AST/bytecode this VM consumes (see `docs/research.txt`,
  section B).

## 3. Product Description

**COR24 Smalltalk v0** is a Tinytalk-class system:

- Hosted entirely as a BASIC program (no C, Python, or Rust in this
  repo). The interpreter language for the *outer* layer is BASIC;
  the BASIC interpreter itself is Pascal, but that is a sibling
  project (`sw-cor24-basic`), not part of v0 deliverables here.
- Integer-only. SmallIntegers are tagged in a single 24-bit word.
- Image-resident: classes, methods, and bytecode are loaded into the
  scratch heap at startup; the BASIC program *is* the image loader.
- Bytecode-interpreted. Every Smalltalk message send goes through a
  small dispatch loop written in BASIC.
- Demos run from the BASIC REPL. The first milestone is `3 + 4`
  evaluated as a real message send to SmallInteger>>+.

Dialect name: **COR24 Smalltalk v0** (a.k.a. "Tinytalk-on-BASIC").

## 4. Functional Requirements

### 4.1 Object Model

- Single uniform object reference: a 24-bit integer.
  - Tag bit 0 = 1: SmallInteger, value = ref shifted right 1.
  - Tag bit 0 = 0: heap pointer, value = byte index into heap.
- Heap objects share a 3-word header: class index, size, format.
- Built-in classes (compile-time fixed indices for v0):
  Object, Class, SmallInteger, True, False, UndefinedObject,
  Array, Symbol, Method, Block.
- One global symbol table indexes selectors by integer id.

### 4.2 Message Sends

- Three syntactic forms accepted by the (text) parser: unary,
  binary, keyword. All three lower to the same VM operation:
  `send(selectorId, argc)`.
- Method lookup walks the receiver class chain. `doesNotUnderstand:`
  is a single primitive trap in v0 (prints a message and halts).
- Polymorphism is real: `+` on SmallInteger and `+` on a future
  Counter are different methods, dispatched by class.

### 4.3 Bytecode Set (target: ~14 opcodes)

`HALT`, `PUSH_SELF`, `PUSH_LIT`, `PUSH_TEMP`, `STORE_TEMP`,
`PUSH_FIELD`, `STORE_FIELD`, `SEND`, `RETURN_TOP`, `POP`,
`JUMP`, `JUMP_IF_FALSE`, `PUSH_INT`, `PRIMITIVE`.

The set is intentionally too small for production — it is wide
enough to express the demo programs and small enough to keep the
BASIC dispatch loop legible.

### 4.4 Primitives (v0)

| # | Primitive            | Notes                                  |
|---|----------------------|----------------------------------------|
| 1 | SmallInt add         | tagged add, overflow wraps             |
| 2 | SmallInt subtract    |                                        |
| 3 | SmallInt multiply    |                                        |
| 4 | SmallInt less-than   | returns True/False object              |
| 5 | print SmallInt       | host PRINT of decimal value            |
| 6 | new instance         | allocate from class                    |
| 7 | at:                  | indexed read on Array                  |
| 8 | at:put:              | indexed write on Array                 |
| 9 | identityEquals       | reference comparison                   |

### 4.5 Demos (Acceptance)

- **D1 — `3 + 4`**: tagged-int receiver, primitive-1 dispatch,
  prints `7`. Proves the whole pipeline (parser/loader → bytecode →
  dispatch → primitive → result).
- **D2 — Counter**: a class with one instance variable `value`
  and methods `init`, `incr`, `value`. Sequence `c init incr incr
  value print` should print `2`. Proves heap allocation, slot
  read/write, and user-defined methods dispatched by class.
- **D3 — Boolean**: `5 < 10 ifTrue: [42] ifFalse: [0]` prints `42`.
  Proves block-like control flow without escape closures.

### 4.6 Image Format

The Smalltalk image is a sequence of integers loaded into the BASIC
scratch heap (`PEEK`/`POKE` addresses 0..N-1). v0 ships a single
prebuilt image embedded directly in the BASIC program as a sequence
of `POKE` lines (since v1 BASIC has no `DATA`/`READ`). Image bring-up
time is dominated by these POKEs — acceptable for v0.

A proper image loader (text or paper-tape) is out of scope for v0
(see Section 6).

### 4.7 REPL Surface

Two surfaces, both implemented as BASIC programs:

1. **Canned demo program**: `RUN`-able BASIC source that POKEs the
   image, evaluates a fixed expression, prints the result.
2. **Mini Smalltalk REPL**: BASIC reads a line, runs a tiny parser
   that recognizes the `D1`/`D2`/`D3` shapes only, builds bytecode
   into the scratch buffer, executes it. This is *not* a full
   Smalltalk parser; it is a hand-written recursive-descent reader
   for exactly the demo grammar.

## 5. Non-Functional Requirements

### 5.1 No-language constraints

- **No C, Python, or Rust** in this repository. v0 source is
  BASIC (the demo programs / image loader / mini REPL) and Markdown
  (docs). The BASIC interpreter itself lives in `../sw-cor24-basic`
  and is Pascal — that is fine, because we treat BASIC as a
  language we *use*, not one we *implement* here.

### 5.2 Smallness

- Total demo program (image POKEs + VM loop + parser) must fit in
  the BASIC v1 program area: `PS = 16384` bytes of tokenized lines.
- The Smalltalk heap must fit in the BASIC v1 PEEK/POKE scratch
  region: 1024 24-bit words. v0 reserves 768 words for the heap and
  256 for VM stacks/temps.

### 5.3 Educational clarity

- Every step of a message send is visible: receiver fetch, class
  lookup, method dictionary scan, activation, return.
- `STOP` after each interpreter inner step (toggleable) leaves the
  REPL state in BASIC variables `A..Z` so a user can `PRINT` them.

### 5.4 Positioning

| | Pascal | BASIC | Smalltalk v0 |
|---|---|---|---|
| Execution | Compiled | Interpreted | Interpreted-on-BASIC (two layers) |
| Style | Structured, typed | Dynamic, line-numbered | Object-message, class-based |
| Use case | Apps | Bring-up, scripting | Teaching late-binding, OO mental model |

## 6. Out of Scope (v0)

- Full Smalltalk-80 semantics (no metaclasses, no real Block
  closures, no `become:`, no reified contexts).
- Garbage collection. v0 uses a bump-pointer arena. `NEW` resets
  the heap.
- Floating point, fractions, large integers. SmallInteger only.
- Strings as first-class objects (only Symbols / interned ids).
- Image save/load to file or tape. The image is generated at boot.
- A general Smalltalk text parser. The mini REPL recognizes only
  the demo grammar.
- Visual tile / tree editor (described in `docs/research.txt`,
  section B). That is a separate project that would emit the same
  bytecode this VM consumes.
- Self-hosting (compiler-in-Smalltalk). v0 is bytecode-only at the
  Smalltalk layer; classes and methods are authored in BASIC POKE
  sequences.

## 7. Implementation Language

- **Outer layer**: BASIC (COR24 BASIC v1, dialect documented in
  `../sw-cor24-basic/docs/prd.md`). All v0 source files in this
  repo end in `.bas`.
- **Substrate**: COR24 BASIC interpreter (Pascal, on the p-code VM).
  Sibling repo. Treated as a fixed dependency for v0 — feature
  requests filed there, not implemented here. See
  `docs/plan.md` § "BASIC feature requests".
- **Forbidden in this repo**: C, Python, Rust. (The sibling Pascal
  compiler uses C upstream; that is not "in this project".)

## 8. Dependencies

| Dependency | Repo | Required For |
|---|---|---|
| BASIC interpreter | `sw-cor24-basic` | Hosts the Smalltalk VM |
| p-code VM | `sw-cor24-pcode` | Runs BASIC |
| COR24 emulator | `sw-cor24-emulator` | Runs everything |

## 9. Success Criteria

- Demo D1 (`3 + 4`) prints `7` via real message-send dispatch (not
  a BASIC `PRINT 3+4`).
- Demo D2 (Counter) prints `2` after `init / incr / incr / value`.
- Demo D3 (Boolean) prints `42` via `ifTrue: / ifFalse:` dispatched
  through True and False objects.
- The list of *required* BASIC v1 changes to make the demos
  practical is small and documented (see `docs/plan.md`).
- A reader who knows BASIC and has never seen Smalltalk can follow
  one full message send by single-stepping the BASIC source.
