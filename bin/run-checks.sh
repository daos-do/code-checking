#!/usr/bin/env bash
# Copyright 2026 Hewlett Packard Enterprise Development LP
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${REPO_ROOT}"

echo "[check] verifying required paths"
required_paths=(
  "README.md"
  "LICENSE"
  "bin/run-checks.sh"
  "checks/pre-commit_d"
  "ide/reference/recommended_settings.yml"
)

for p in "${required_paths[@]}"; do
  if [[ ! -e "$p" ]]; then
    echo "Missing required path: $p" >&2
    exit 1
  fi
done

echo "[check] validating shell script syntax"
while IFS= read -r -d '' file; do
  bash -n "$file"
done < <(find bin checks -type f -name '*.sh' -print0)

echo "All checks passed."
