# Step: top-level-st

Add `main` blocks to the `.st` source format so a complete demo
(methods + top-level expression) lives in a single `.st` file
with no hand-written BASIC driver. The end goal is:

```sh
$ ./scripts/run-st examples/d2_counter.st
2
```

Where the entire program is Smalltalk text and the only `.bas`
content used is `src/vm.bas` (VM substrate).

## Why

Today every demo splits across:
1. `examples/<demo>.st` — methods (Smalltalk)
2. `examples/<demo>.bas` — top-level driver, hand-assembled
   bytecode via `LET O(idx)=val` lines

The driver `.bas` is the last hand-written hand-assembled
bytecode in the repo. After this step, even that goes away;
each demo is one `.st` file plus the shared VM.

## .st syntax extension

Add a `main` block, syntactically identical to a `method` block
but introduced by the keyword `main`:

```st
class Counter slots value
method init ...
method incr ...
method value ...

main
  c := Counter new.
  c init.
  c incr.
  c incr.
  c value print
end
```

The `main` block is compiled to bytecode like a method body, but
with these differences:

- No class/selector. It is the top-level expression evaluated by
  the VM's first dispatch loop entry.
- `c := Counter new` introduces a NEW class of variable: a
  top-level local. These need a small extension to the runtime
  (one slot per top-level local on the eval stack, or use
  PUSH_TEMP indices reserved for top-level).
- The final statement's value is printed via `print` (which
  becomes `SEND print, 0` to the SmallInt or whatever the
  receiver is). Or use explicit `^ <expr> print` like methods do.

The existing `args` directive is reused here — `main` can have
no args.

## Compiler / build pipeline changes

1. `tools/stc.awk` recognises `main` and emits its bytecode at a
   fixed offset (e.g., bytecode pool index 64+) plus a small
   "driver stub" header BAS that:
     - inits E/S/F
     - GOSUBs 100 (image install)
     - sets M = main-start, L = main-length, P = 0, R = 0
     - GOSUBs 12000 (dispatch)
     - prints any error
     - END
2. `scripts/build.sh` and `scripts/run.sh`: keep working for
   demos that have a hand-written `.bas` driver. NEW: a
   `scripts/run-st.sh <path-to-.st>` that:
     - compiles `.st` to a complete `.bas` (image + driver
       stub from the `main` block)
     - cats with `src/vm.bas`
     - runs through sibling BASIC

## Migration

After the compiler accepts `main`:

- Add `main` blocks to `examples/d{1,2,3,4,6,7}_*.st` capturing
  the top-level expressions that today live in the per-demo
  `.bas` driver.
- D5 (interactive REPL loop) and D8 (stepper variant) keep
  their `.bas` drivers since their top-level needs `INPUT`
  loops or `LET J=1` flag setting that aren't expressible in
  `.st` v0.
- Delete the `.bas` drivers for the migrated demos. `examples/`
  becomes mostly `.st`.

## Required: `Counter new`

`new` is a primitive (#13 in the selector table) but the v0 VM
never wired it up properly — D2/D7 drivers bypass it via direct
`GOSUB 9700` (ALLOC). For `main` blocks to work we need either:

- A working `new` primitive that takes a class id as receiver
  and ALLOCs an instance, or
- A different bootstrap sequence for `main` (e.g., the compiler
  emits an inline ALLOC-call sequence).

Pick the simplest path. If `new` needs proper class objects
(metaclasses) that's out of scope; the alternative is a small
"alloc-class N" pseudo-bytecode the compiler emits that the VM
recognises as a synthetic ALLOC.

## Definition of done

- `examples/d2_counter.st` runs end-to-end via
  `./scripts/run-st examples/d2_counter.st` and prints `2`.
  Same for D1, D3, D4, D6, D7.
- `examples/d{1,2,3,4,6,7}_*.bas` (driver files) deleted.
- `docs/st-source.md` documents `main` syntax and the new
  print convention.
- D5 calc and D8 stepper still work via the legacy
  `scripts/run.sh` path (they keep their `.bas` drivers).
- The single Smalltalk source in this repo to read for "what
  is this demo doing?" is the `.st` file - no need to read
  any `.bas` to understand the program logic.

## Scope creep to avoid

- A real text REPL (read user-typed Smalltalk, parse, run)
  belongs in the v1-dialect saga; it needs strings.
- Cascades and unary message sends with explicit precedence at
  arbitrary depth: keep current `parse_expr`/`parse_unary`/
  `parse_atom` recursion. Don't rewrite the parser.
- Garbage collection / heap reset between sends: still
  bump-allocator only.
