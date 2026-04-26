# sw-cor24-smalltalk

COR24 Smalltalk v0 — a tiny integer-only "Tinytalk" hosted entirely
in COR24 BASIC v1, in the spirit of the ~1000-line BASIC-hosted
Smalltalk evaluator that Alan Kay's group built in 1972.

## Overview

This project demonstrates the Smalltalk execution model
(objects, classes, message sends, late binding, bytecode
dispatch) on the smallest possible substrate: a 26-variable,
no-array, integer-only BASIC interpreter. Every Smalltalk
message goes through real `CLASSOF -> LOOKUP -> ACTIVATE ->
primitive-or-frame-push`, hand-coded as `GOSUB` chains and
`PEEK`/`POKE` against BASIC's 1024-word scratch RAM.

The point is not speed (it is slow). The point is to make the
mental model of object-oriented dispatch *visible*: every step
the VM takes is a numbered BASIC line you can single-step through.

## Architecture

```
+---------------------------------------------+
|  Layer 4: Smalltalk Image                   |
|  Class table, method dictionaries,          |
|  bytecodes, symbols. Lives in the BASIC     |
|  PEEK/POKE scratch heap (addresses 0..767). |
+---------------------------------------------+
|  Layer 3: Tinytalk VM                       |
|  BASIC subroutines: heap helpers, dispatch  |
|  loop, message send, primitives. Source:    |
|  src/vm.bas (this repo).                    |
+---------------------------------------------+
|  Layer 2: COR24 BASIC v1                    |
|  Tokenized line storage, dispatch, eval,    |
|  PEEK/POKE scratch RAM (1024 24-bit words). |
|  Sibling: ../sw-cor24-basic.                |
+---------------------------------------------+
|  Layer 1: P-code VM                         |
|  Stack machine running the BASIC            |
|  interpreter (Pascal compiled to p-code).   |
+---------------------------------------------+
|  Layer 0: COR24 hardware / emulator         |
+---------------------------------------------+
```

Three nested fetch/decode/execute loops (p-code VM, BASIC
interpreter, Tinytalk VM) are running at all times. That is
intentional.

## Dialect: COR24 Smalltalk v0

- Single uniform reference type: a 24-bit signed BASIC integer.
- **Tagged SmallIntegers** in the low bit:
  - `ref bit 0 = 1` : SmallInteger, value = `(ref - 1) / 2`.
  - `ref bit 0 = 0` : heap pointer, address = `ref / 2`.
- 14 bytecodes (`HALT`, `PUSH_SELF`, `PUSH_LIT`, `PUSH_TEMP`,
  `STORE_TEMP`, `PUSH_FIELD`, `STORE_FIELD`, `SEND`,
  `RETURN_TOP`, `POP`, `JUMP`, `JUMP_IF_FALSE`, `PUSH_INT`,
  `PRIMITIVE`).
- 6 primitives in v0 (SmallInt + - * <, print, new).
- Built-in classes: `Object`, `Class`, `SmallInteger`, `True`,
  `False`, `UndefinedObject`, plus user classes (e.g. `Counter`).
- Block evaluation is **eager** in v0: callers compute both
  branches of `ifTrue:ifFalse:` and pass them as arguments; the
  receiver class selects which one to return. Lazy block
  evaluation needs real closures and is out of scope.

See `docs/design.md` for the full bytecode set, object encoding,
method dictionary layout, frame format, and `docs/architecture.md`
for the address map within scratch RAM.

## Positioning

| | Pascal | BASIC | Smalltalk v0 |
|---|---|---|---|
| Execution | Compiled to p-code | Interpreted on p-code VM | Interpreted on BASIC (two layers of interpretation) |
| Style | Structured, typed | Dynamic, line-numbered | Object-message, class-based |
| Use case | Apps | Bring-up, scripting | Teaching late-binding and the OO mental model |

## Status

**v0 demos all run.** Three demonstrations of the message-send
model work end-to-end:

| Demo | Source | Output | What it proves |
|---|---|---|---|
| D1 | `examples/d1_add.bas` | `7` | `3 + 4` via `SmallInteger>>+` (primitive method) |
| D2 | `examples/d2_counter.bas` | `2` | `Counter` class with one instance variable; user-defined methods (`init`, `incr`, `value`); nested send (`incr` calls `+`) across user/primitive method boundaries |
| D3 | `examples/d3_boolean.bas` | `42` | `5 < 10 ifTrue: 42 ifFalse: 0` via True/False objects with their own polymorphic `ifTrue:ifFalse:` methods. No native `IF` is used to make the choice — the receiver class does. |
| D4 | `examples/d4_max.bas` | `5` | `5 max: 3` via `SmallInteger>>max:` whose bytecode uses `JUMP_IF_FALSE` to actually skip the unselected branch — real conditional control flow inside a Smalltalk method, not D3's eager-argument cheat. |
| D5 | `examples/d5_calc.bas` | varies | Interactive integer calculator REPL: prompts for `A`, `op`, `B`, runs `A op B` through the VM, prints the result, loops until `op = 0`. `op` is the selector id (1=+, 2=-, 3=\*, 4=<, 14=max:). The first user-facing program; uses BASIC `INPUT` since v1 has no string variables for a true source REPL. |
| D6 | `examples/d6_fact.bas` | `120` | `5 fact` via a *recursive* `SmallInteger>>fact` whose body uses `JUMP_IF_FALSE` to skip past the recursive branch at the base case. Verified up to `10 fact = 3628800` (recursion depth 11, comfortably within the 19-frame stack). The first proof that the v0 frame stack handles non-trivial nesting. |
| D7 | `examples/d7_bounded.bas` | `5` | `BoundedCounter` extends `Counter`, overriding `incr` to cap at 5; `init` and `value` are inherited via the superclass walk added to LOOKUP. After 6 increments from 0, the value clamps at 5 instead of reaching 6. The first proof that v0 dispatches via inheritance (the receiver's class is consulted first; misses walk `class_super[]`). |
| Hello | `examples/hello.st` | `hello, world` | First v1-dialect demo. Uses `Transcript show: 'hello, world'. Transcript cr.` with String literals from the per-image literal pool. |
| D8 | `examples/d8_step.bas` | trace + `7` | D1's `3 + 4` with the per-opcode `STOP`/`CONT` stepper enabled (set scalar `J = 1` before invoking dispatch). `tests/d8_step.in` interleaves `PRINT P;S` and `CONT` with each STOP, producing a register trace from `P=0 S=0` through the four-opcode dispatch to the final `7`. The first interactive Smalltalk debugger v0 has had. |

All six upstream BASIC feature requests have shipped and are
fully dogfooded.  v0.1 is the milestone "Tinytalk + every BASIC
FR adopted + first .st compiler + single-file demos."  v1.0
adds Strings + a literal pool + Transcript primitives so
demos can emit human-readable text:

```sh
$ ./scripts/run-st.sh examples/hello.st
hello, world
```

See `docs/status.md` for the running history.

| FR | Feature | Dogfooded here? |
|---|---|---|
| FR-1 | `DIM` arrays | **yes** — VM, images, drivers all use single-letter `DIM` arrays; zero `PEEK`/`POKE` in v0 source |
| FR-2 | `DATA` / `READ` / `RESTORE` | **yes** — image files cut from 371 to 98 lines |
| FR-3 | `ON expr GOTO/GOSUB` | **yes** — three IF-chain dispatchers became single-line `ON GOSUB`s; O(1) dispatch |
| FR-4 | `MOD` | **yes** — `ISINT` now uses `V MOD 2` |
| FR-5 | bitwise BAND/BOR/BXOR/SHL/SHR | **yes** — `TOINT`/`MKINT`/`PADDR` use `SHR`/`SHL`/`BOR` |
| FR-6 | `CONT` after `STOP` | **yes** — interactive single-stepper via scalar `J` flag; see `examples/d8_step.bas` |

The pre-FR snapshot is preserved at the
[`minimal-basic-with-workarounds`](https://github.com/sw-embed/sw-cor24-smalltalk/releases/tag/minimal-basic-with-workarounds)
tag.

## Building and running

The "build" step is text concatenation. Each demo is one or more
`.bas` source fragments (a per-demo image header, the shared
VM core, a per-demo driver) cat'd together and run through the
sibling BASIC interpreter.

```sh
# Build and run any of the three demos.
# Single-file Smalltalk demos (run-st.sh):
./scripts/run-st.sh examples/d1_add.st       # -> 7
./scripts/run-st.sh examples/d2_counter.st   # -> 2
./scripts/run-st.sh examples/d3_boolean.st   # -> 42
./scripts/run-st.sh examples/d4_max.st       # -> 5
./scripts/run-st.sh examples/d6_fact.st      # -> 120
./scripts/run-st.sh examples/d7_bounded.st   # -> 5

# Legacy .bas-driver demos (run.sh):
./scripts/run.sh d5_calc       # interactive REPL; see "Test transcripts" below
./scripts/run.sh d8_step       # stepper variant of D1; see d8 row in demos
```

### Test transcripts

`scripts/build.sh` looks for `tests/<demo>.in` and, if present,
splices its contents between the trailing `RUN` and `BYE` so
`INPUT` statements receive canned data. This is how `d5_calc`
becomes reproducible. To run `d5_calc` *interactively*, move the
transcript out of the way:

```sh
mv tests/d5_calc.in tests/d5_calc.in.bak
./scripts/run.sh d5_calc       # type integers at each prompt
mv tests/d5_calc.in.bak tests/d5_calc.in
```

Each script writes `build/<demo>.bas` and feeds it to the
sibling `../sw-cor24-basic/scripts/run-basic.sh`, which runs it
under `pv24t` (the host-side p-code interpreter).

## Substrate smoke tests

`examples/smoke/` contains four standalone BASIC programs that
verify the four substrate behaviours v0 depends on. Run them via
`scripts/run-bare.sh` if you want to confirm the host BASIC still
behaves as expected:

```sh
./scripts/run-bare.sh examples/smoke/peek_word_store.bas
./scripts/run-bare.sh examples/smoke/tag_bit.bas
./scripts/run-bare.sh examples/smoke/gosub_chain.bas
./scripts/run-bare.sh examples/smoke/prog_size.bas
```

## Dependencies

| Project | Repo | Role |
|---------|------|------|
| BASIC interpreter | `../sw-cor24-basic` | Hosts the Smalltalk VM |
| P-code VM | `../sw-cor24-pcode` | Runs BASIC |
| COR24 emulator | `../sw-cor24-emulator` | Runs everything |

This repository contains **no C, Python, or Rust source**. The VM
is BASIC; the BASIC interpreter itself is Pascal in the sibling
project (out of scope here).

## Documentation

- [Product Requirements](docs/prd.md)
- [Architecture](docs/architecture.md)
- [Design](docs/design.md) (object encoding, bytecodes, primitives,
  BASIC v1 shortcomings catalogue)
- [Smalltalk source format](docs/st-source.md) (`.st` syntax
  reference for `tools/stc.awk`)
- [Implementation Plan](docs/plan.md)
- [Status](docs/status.md)
- [Research Notes](docs/research.txt) (the conversation that
  defined the project)

## License

MIT. See `LICENSE`.

Copyright (c) 2026 Michael A Wright.
