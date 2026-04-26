#!/bin/bash
# build.sh — Assemble a Smalltalk demo by concatenating image header,
# the VM, and the demo driver into a single .bas file under build/.
#
# Usage: ./scripts/build.sh <demo>
#   where <demo> is one of: d1_add, d2_counter, d3_boolean
#
# The output build/<demo>.bas is fed to the sibling BASIC interpreter
# by scripts/run.sh.
set -euo pipefail

DEMO="${1:?Usage: $0 <demo>  (d1_add|d2_counter|d3_boolean)}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

VM="$REPO_DIR/src/vm.bas"
IMG="$REPO_DIR/src/image_${DEMO#d?_}.bas"
case "$DEMO" in
  d1_add)      IMG="$REPO_DIR/src/image_d1.bas" ;;
  d2_counter)  IMG="$REPO_DIR/src/image_d2.bas" ;;
  d3_boolean)  IMG="$REPO_DIR/src/image_d3.bas" ;;
  d4_max)      IMG="$REPO_DIR/src/image_d4.bas" ;;
  d5_calc)     IMG="$REPO_DIR/src/image_d5.bas" ;;
  d6_fact)     IMG="$REPO_DIR/src/image_d6.bas" ;;
  d7_bounded)  IMG="$REPO_DIR/src/image_d7.bas" ;;
  d8_step)     IMG="$REPO_DIR/src/image_d1.bas" ;;
  *) echo "unknown demo: $DEMO" >&2 ; exit 2 ;;
esac
DRV="$REPO_DIR/examples/${DEMO}.bas"
OUT="$REPO_DIR/build/${DEMO}.bas"

# If an .st source exists for this demo, compile it instead of
# using the hand-written src/image_<demo>.bas.  Generated images
# go to build/ and are byte-equivalent to the hand-written ones
# for D2 today (see docs/st-source.md).
ST_SRC="$REPO_DIR/examples/${DEMO}.st"
if [ -f "$ST_SRC" ]; then
  mkdir -p "$REPO_DIR/build"
  STC="$REPO_DIR/tools/stc.awk"
  GEN_IMG="$REPO_DIR/build/image_${DEMO}.bas"
  "$STC" < "$ST_SRC" > "$GEN_IMG"
  IMG="$GEN_IMG"
  echo "compiled $ST_SRC -> $GEN_IMG"
fi

for f in "$VM" "$IMG" "$DRV"; do
  if [ ! -f "$f" ]; then
    echo "missing source: $f" >&2
    exit 1
  fi
done

mkdir -p "$REPO_DIR/build"

# Concatenation order matters. The image header POKEs class table
# and methods, the VM defines GOSUB-able subroutines (must come
# before the driver invokes them), the driver hand-assembles the
# top-level bytecode and starts the dispatch loop.
#
# Each fragment uses a non-overlapping line-number range; see
# docs/architecture.md section 7. We rely on that, not on cat
# order, for correctness.
cat "$IMG" "$VM" "$DRV" > "$OUT"

# If a test transcript exists, splice it in between the trailing
# RUN and BYE lines so INPUT statements receive the canned data.
# Used by interactive demos (D5 calc) and any later REPL-style
# steps. Pure-batch demos (D1..D4) ignore this branch.
INPUT_FILE="$REPO_DIR/tests/${DEMO}.in"
if [ -f "$INPUT_FILE" ]; then
  awk -v inputs="$INPUT_FILE" '
    /^RUN$/ {
      print
      while ((getline line < inputs) > 0) print line
      close(inputs)
      next
    }
    { print }
  ' "$OUT" > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"
  echo "spliced $INPUT_FILE into $OUT"
fi

echo "wrote $OUT"
