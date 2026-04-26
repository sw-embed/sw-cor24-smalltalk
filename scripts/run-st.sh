#!/bin/bash
# run-st.sh - Compile a .st source file and run it through the
# sibling BASIC interpreter.
#
# Usage: ./scripts/run-st.sh <path/to/file.st>
#
# Pipeline:
#   tools/stc.awk < .st > build/<name>.bas    (image + main + driver)
#   cat build/<name>.bas src/vm.bas > build/<name>_full.bas
#   ../sw-cor24-basic/scripts/run-basic.sh build/<name>_full.bas
set -euo pipefail

ST="${1:?Usage: $0 <path/to/file.st>}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BASIC_DIR="$REPO_DIR/../sw-cor24-basic"

if [ ! -x "$BASIC_DIR/scripts/run-basic.sh" ]; then
  echo "sibling not found at $BASIC_DIR" >&2
  exit 1
fi
if [ ! -f "$ST" ]; then
  echo "source not found: $ST" >&2
  exit 1
fi

NAME=$(basename "$ST" .st)
mkdir -p "$REPO_DIR/build"

STC="$REPO_DIR/tools/stc.awk"
COMPILED="$REPO_DIR/build/${NAME}_compiled.bas"
FULL="$REPO_DIR/build/${NAME}_full.bas"

"$STC" < "$ST" > "$COMPILED"
cat "$COMPILED" "$REPO_DIR/src/vm.bas" > "$FULL"
printf 'RUN\nBYE\n' >> "$FULL"
exec "$BASIC_DIR/scripts/run-basic.sh" "$FULL"
