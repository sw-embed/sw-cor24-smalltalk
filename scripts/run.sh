#!/bin/bash
# run.sh — Build a demo and run it through the sibling BASIC.
# Usage: ./scripts/run.sh <demo>
set -euo pipefail

DEMO="${1:?Usage: $0 <demo>  (d1_add|d2_counter|d3_boolean)}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BASIC_DIR="$REPO_DIR/../sw-cor24-basic"

if [ ! -x "$BASIC_DIR/scripts/run-basic.sh" ]; then
  echo "sibling not found at $BASIC_DIR" >&2
  exit 1
fi

"$SCRIPT_DIR/build.sh" "$DEMO"
exec "$BASIC_DIR/scripts/run-basic.sh" "$REPO_DIR/build/${DEMO}.bas"
