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

Six upstream feature requests are filed against `sw-cor24-basic`
(issues #2-#7) for parallel development of v0.1 cleanups:

| FR | sw-cor24-basic issue | Unblocks (saga) |
|---|---|---|
| FR-2 DATA / READ / RESTORE | sw-embed/sw-cor24-basic#2 | refactor-image-data |
| FR-1 DIM integer arrays | sw-embed/sw-cor24-basic#3 | refactor-vm-arrays |
| FR-3 ON expr GOTO/GOSUB | sw-embed/sw-cor24-basic#4 | refactor-dispatch-on |
| FR-4 MOD operator | sw-embed/sw-cor24-basic#5 | refactor-mod-and-bits |
| FR-5 Bitwise BAND/BOR/BXOR/SHL/SHR | sw-embed/sw-cor24-basic#6 | refactor-mod-and-bits |
| FR-6 CONT after STOP | sw-embed/sw-cor24-basic#7 | debug-cont-stepper |

Each FR unblocks one independent, parallel-mergeable refactor in
this repo. None blocks the demos that already run.

## Building and running

The "build" step is text concatenation. Each demo is one or more
`.bas` source fragments (a per-demo image header, the shared
VM core, a per-demo driver) cat'd together and run through the
sibling BASIC interpreter.

```sh
# Build and run any of the three demos.
./scripts/run.sh d1_add
./scripts/run.sh d2_counter
./scripts/run.sh d3_boolean
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
- [Implementation Plan](docs/plan.md)
- [Status](docs/status.md)
- [Research Notes](docs/research.txt) (the conversation that
  defined the project)

## License

MIT. See `LICENSE`.

Copyright (c) 2026 Michael A Wright.
