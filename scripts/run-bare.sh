#!/bin/bash
# run-bare.sh — Run a single .bas file directly through the sibling
# BASIC, with no image-header / vm.bas concatenation. Used by the
# smoke tests under examples/smoke/, which are standalone BASIC
# programs that exercise one substrate property each.
#
# Usage: ./scripts/run-bare.sh <path/to/file.bas>
set -euo pipefail

BAS="${1:?Usage: $0 <path/to/file.bas>}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BASIC_DIR="$REPO_DIR/../sw-cor24-basic"

if [ ! -x "$BASIC_DIR/scripts/run-basic.sh" ]; then
  echo "sibling not found at $BASIC_DIR" >&2
  exit 1
fi

exec "$BASIC_DIR/scripts/run-basic.sh" "$BAS"
