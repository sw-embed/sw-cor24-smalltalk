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
program    = { class } [ "end" ] .
class      = "class" classname [ "extends" parentname ]
             [ "slots" varname { varname } ]
             { method } .
method     = "method" selector
             [ "args" argname { argname } ]
             ( body | primdir ) .
primdir    = "primitive" integer .
body       = { statement } .
statement  = ( "^" expr
             | varname ":=" expr
             | "if" expr ) [ "." ] .
expr       = unary { binop unary } .
unary      = atom { unaryid } .
atom       = "self" | integer | name | "(" expr ")" .
binop      = "+" | "-" | "*" | "<" | "=" .
unaryid    = identifier in selector table that is not a binop
             and contains no ":" (i.e. not a keyword) .
name       = argname | varname .
classname  = identifier .  (* must be in compiler's class table *)
parentname = classname .
selector   = identifier (binary | unary | keyword form, must be
                         in compiler's selector table) .
argname    = identifier .  (* declared via 'args' line *)
varname    = identifier .  (* slot of the enclosing class *)
integer    = ["-"] digit { digit } .
identifier = letter { letter | digit } .
```

Comments: `#` starts a line comment to end of line. Periods
(`.`) and tabs are stripped. Parens are tokenised as separate
atoms.

## Statement: `if EXPR`

`if EXPR` does not branch by itself. It compiles the condition
and emits `JUMP_IF_FALSE 0`, recording the offset position. The
**next** `^` statement triggers backpatch: the JUMP_IF_FALSE
offset becomes "skip past the bytecode of the next return". Any
non-return statements between `if` and the first `^` (e.g.
assignments) become part of the guarded block. After the `^`
fires, control falls through to whatever comes next.

This is the v0 lowering of Smalltalk's `cond ifTrue: [...]
ifFalse: [...]` when both branches end in `^`. See `examples/
d4_max.st` and `examples/d6_fact.st`.

## Inheritance: `class CHILD extends PARENT`

The compiler:
1. Looks up `PARENT`'s slot list and copies it to `CHILD`'s
   slot table (so slot offsets stay stable).
2. Records the relationship as a `LET K(child_id) = parent_id`
   line in the generated image header. At image-load time, this
   sets `class_super[child]` so the VM's superclass walk in
   LOOKUP can resolve inherited methods.

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

- Keyword messages **inside method bodies** (`x at: i put: v`,
  `x ifTrue: y ifFalse: z`). Drivers can issue keyword sends
  via hand-assembled `SEND <selector-id> <argc>` bytecode (D3,
  D4, D5, D7 drivers do this); inside a method body, the
  workaround is the `if EXPR` lowering for the
  `ifTrue:ifFalse:` shape.
- Cascades (`a; b; c`).
- Block literals (`[ ... ]`). Block-shaped control flow lowers
  to the `if` directive (which emits `JUMP_IF_FALSE`).
- String literals. Coming in v1 dialect (issue #4).
- Class methods (`Counter class>>new`). v0 has no metaclasses.
- Local temp variables inside methods. Temps are limited to
  args declared via the `args` line; intermediate values must
  re-evaluate or use parens.

## Top-level: `main` block

A `.st` file may end with a `main` block containing a single
expression (or a sequence of value statements). The compiler
emits the main bytecode at `O(64..)`, prepends a small driver
stub at lines 1..99 that GOSUBs the image install and dispatches
the main bytecode, and auto-appends `PRIMITIVE 5` (print) +
`HALT` so the last value statement's result is printed.

```st
class SmallInteger
method +
  primitive 1

main
  3 + 4
end
```

Run with:

```sh
./scripts/run-st.sh examples/d1_add.st
# -> 7
```

`run-st.sh` does:

1. Compile `.st` to a complete `.bas` (driver stub + image
   install + method DATA + main DATA).
2. Cat the compiled output with `src/vm.bas`.
3. Append `RUN\nBYE\n` so the BASIC interpreter executes the
   stored program after all numbered lines (incl. vm.bas
   helpers) are loaded.

## `ClassName new` shorthand

Inside a `main` (or any expression) the compiler recognises
`<ClassName> new` as an inline ALLOC sequence:

```
PUSH_INT <class-id>
PUSH_INT <ivar-count>      (from the class's slots declaration)
PRIMITIVE 6                (= ALLOC)
```

`PRIMITIVE 6` (in `src/vm.bas` line 15600) pops both, calls
`ALLOC`, and pushes the resulting tagged heap reference.

Bare class names without a following `new` are an error.

## Compiler invocation

```sh
# Default: full output (driver stub + image + main DATA).
tools/stc.awk < examples/d2_counter.st > build/d2.bas

# Methods-only (legacy .bas-driver demos like D5 calc, D8 stepper).
tools/stc.awk -v MODE=methods_only < examples/d5_calc.st > build/image.bas
```

`scripts/run-st.sh` uses the default mode.
`scripts/build.sh` uses `MODE=methods_only` so legacy `.bas`
drivers can supply their own top-level bytecode.
