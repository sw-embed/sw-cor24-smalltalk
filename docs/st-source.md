# COR24 Smalltalk v0 — `.st` Source Format

Minimal syntax that the host-side compiler (`tools/stc.awk`) can
translate to the `<class> <selector> <bytecount> <bytes...>`
DATA records that `read_and_install_methods` (in `src/vm.bas` at
line 10800) consumes at boot.

This is a **strict subset** of Smalltalk syntax, sufficient for
the Counter / max: / fact / BoundedCounter shapes. It is line-
oriented, has no operator precedence (binary sends evaluate left
to right, like real Smalltalk), and emits one DATA record per
method definition. A separate "driver" still hand-assembles the
top-level expression in BASIC (see `examples/d*.bas`); the
compiler's job is methods only.

## EBNF (informal)

```
program     = { class } [ "end" ] .
class       = "class" classname [ "slots" varname { varname } ]
              { method } .
method      = "method" selector ( body | primdir ) .
primdir     = "primitive" integer .
body        = { statement } .
statement   = ( "^" expr | varname ":=" expr ) [ "." ] .
expr        = atom { binop atom } .
atom        = "self" | integer | varname .
binop       = "+" | "-" | "*" | "<" | "=" .
classname   = identifier .  (* must be in the compiler's class table *)
selector    = "+" | "-" | "*" | "<" | "=" |
              identifier .  (* must be in the compiler's selector table *)
varname     = identifier .  (* slot of the enclosing class *)
integer     = ["-"] digit { digit } .
identifier  = letter { letter | digit } .
```

Comments: `#` starts a line comment to end of line. Periods
(`.`) and tabs are stripped.

## Selector and class id tables

The compiler uses a fixed lookup. New classes / selectors must
be added to `tools/stc.awk` before they can be referenced.

| Selector | id |
|---|---|
| `+` | 1 |
| `-` | 2 |
| `*` | 3 |
| `<` | 4 |
| `print` | 5 |
| `init` | 6 |
| `incr` | 7 |
| `value` | 8 |
| `ifTrue:ifFalse:` | 9 |
| `at:` | 10 |
| `at:put:` | 11 |
| `=` | 12 |
| `new` | 13 |
| `max:` | 14 |
| `fact` | 15 |

| Class | id |
|---|---|
| `Object` | 0 |
| `Class` | 1 |
| `SmallInteger` | 2 |
| `True` | 3 |
| `False` | 4 |
| `UndefinedObject` | 5 |
| `Array` | 6 |
| `Symbol` | 7 |
| `Method` | 8 |
| `Block` | 9 |
| `Counter` | 10 |
| `BoundedCounter` | 11 |

## Worked example: `examples/d2_counter.st`

```st
class SmallInteger
method +
  primitive 1

class Counter slots value
method init
  value := 0.
  ^ self
method incr
  value := value + 1.
  ^ self
method value
  ^ value
end
```

## What each statement compiles to

| Source | Bytecode |
|---|---|
| `primitive N` | `13 N 8` (PRIMITIVE N; RETURN_TOP) |
| `^ self` | `1 8` |
| `^ <int>` | `12 N 8` |
| `^ <var>` | `5 fld 8` |
| `<var> := <int>` | `12 N 6 fld` |
| `<var> := <var>` | `5 fld 6 fld` |
| `<var> := <a> OP <b>` | `<a-bc> <b-bc> 7 sel 1 6 fld` |

`<var>` resolves to its slot index in the current class.

## Expression semantics

Binary sends evaluate **left to right** with no precedence —
Smalltalk's standard binary-message rule. Parentheses are not
yet supported. Use intermediate assignments if grouping is
needed.

So `a + b * c` is `((a + b) * c)`, not `(a + (b * c))`.

## What is *not* in v0 syntax

- Keyword messages with multiple parts (`x at: i put: v`).
  Single-keyword sends like `5 max: 3` need step 016's
  expansion; `ifTrue:ifFalse:` likewise.
- Unary message sends (`x reverse`, `x squared`). The driver-
  level handling of demo top-levels still uses BASIC POKE.
- Cascades (`a; b; c`).
- Block literals (`[ ... ]`). Block-shaped control flow still
  has to lower to `JUMP_IF_FALSE` (D4-style) which the
  compiler doesn't yet emit.
- String literals. Coming in v1 dialect (issue #4).
- Class methods (`Counter class>>new`). v0 has no metaclasses.

## Compiler invocation

```sh
tools/stc.awk < examples/d2_counter.st > build/image_d2.bas
```

The output is an `image_*.bas` file in the same shape as the
hand-written ones in `src/`: a small bootstrap header
(GOSUB 10100, GOSUB 10700, RESTORE, GOSUB 10800, RETURN) plus
DATA records starting at line 500.

`scripts/build.sh` invokes `stc.awk` automatically when
`examples/<demo>.st` exists.
