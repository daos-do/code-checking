#!/usr/bin/env bash
set -euo pipefail

echo "[bootstrap-python] checking for Python 3 runtime"

if ! command -v python3 >/dev/null 2>&1; then
  cat >&2 <<'EOF'
[bootstrap-python] Python 3 was not found.

Install Python 3, then open a new terminal and rerun this script.

Examples:
- Ubuntu/Debian: sudo apt install python3
- macOS (Homebrew): brew install python
EOF
  exit 1
fi

echo "[bootstrap-python] found: python3"
echo "[bootstrap-python] version: $(python3 --version)"
echo "[bootstrap-python] Python bootstrap check passed"
