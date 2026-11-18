#!/bin/sh
# Steal a Snack v2 — headless test runner. One command, no Studio needed.
set -e
cd "$(dirname "$0")/.."
python3 tests/assemble.py
"$HOME/workspace/tools/luau-0.747/luau" tests/_combined.luau
