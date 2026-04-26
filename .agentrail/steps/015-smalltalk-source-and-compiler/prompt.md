# Step: smalltalk-source-and-compiler

Define a minimal `.st` source format for v0 and write a host-side
compiler that produces the same `<class> <selector> <bytecount>
<bytes...>` DATA records the VM consumes today (via
`read_and_install_methods` at `src/vm.bas` line 10800).

This is the missing piece between "the VM works" and "you can
write Smalltalk." Today every method body lives as raw bytes
hand-typed into `image_d*.bas` `DATA` lines; English-comment
"source" sits next to it but is not parsed. After this step,
*one* demo (D2 Counter, the canonical example) is generated
from a real text source.

## Constraints

- No C, Python, or Rust in this repo (project rule). Acceptable
  host-side languages: shell + awk, Pascal (sibling toolchain),
  or BASIC itself if you can stomach the no-string-variable
  constraint. Default recommendation: **awk**, since it has
  excellent string handling and ships with every POSIX system.
- The compiler is a build-time tool. It runs on the host
  machine, reads a `.st` file, writes an `image_*.bas` file.
  The generated file is build output (add to `.gitignore`).
- Keep the `.st` syntax small. v0 needs:
  - class declarations with named instance variables
  - method definitions (unary, binary, keyword forms)
  - sends (unary, binary, keyword)
  - literals (small integer)
  - `self`, instance-variable read/write, `^` return
  - `JUMP_IF_FALSE`-style conditionals if you want to support
    `max:`-shape methods (D4); otherwise leave that for a
    later step.

## Deliverables

1. `docs/st-source.md` documenting the `.st` syntax. Include
   the EBNF and at least three worked examples (literal expr,
   user method, class with multiple methods).
2. `tools/stc.awk` (or whatever language you pick — the
   filename should reflect the choice) that compiles a single
   `.st` file to its corresponding `image_<demo>.bas`. The
   output must be byte-for-byte equivalent to one of the
   existing hand-written `image_d*.bas` so we have a known-good
   diff target.
3. `scripts/build.sh` updated to invoke the compiler when
   `examples/<demo>.st` exists, generating `build/image_<demo>.bas`
   on the fly. The cat order doesn't change.
4. `examples/d2_counter.st` as the first source-coded demo.
   Selector ids and class ids should match what `src/image_d2.bas`
   uses today; the compiler picks them deterministically (e.g.,
   maintain a small lookup table at the top of the compiler that
   records `+ -> 1`, `init -> 6`, etc.).
5. The build of D2 from `examples/d2_counter.st` produces output
   identical to today's hand-written `src/image_d2.bas`. Add a
   diff check to the build (warn but don't fail if they differ).
6. D2 still prints `2`.

## Out of scope

- Migrating D1, D3, D4, D5, D6, D7 to `.st` source — that's the
  next step (`016-migrate-demos-to-st`).
- A general Smalltalk-80 parser. v0 supports only the syntactic
  subset the seven demos need.
- A self-hosted compiler (Smalltalk compiler written in
  Smalltalk). Way out of scope.
- Symbolic selectors and class names at runtime. Selectors and
  class ids stay as integers in DATA; the compiler resolves
  names statically.

## Definition of done

- `docs/st-source.md` exists and is accurate.
- `tools/stc.awk` (or chosen language) compiles
  `examples/d2_counter.st` -> identical bytes to today's
  `src/image_d2.bas`.
- `scripts/run.sh d2_counter` still prints `2` (using the
  generated image).
- Status doc records the pipeline change: hand-typed bytes ->
  generated from `.st` source.
- Honest report of where the syntax is too narrow to express
  the other six demos (so the next step has a clear scope).
