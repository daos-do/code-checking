#!/usr/bin/env bash
# Copyright 2026 Hewlett Packard Enterprise Development LP
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TARGET_ROOT="$(pwd)"
MODE="changed"
BASE_REF="${GITHUB_BASE_REF:-}"
FIX_MODE=0

usage() {
  cat <<'EOF'
Usage: run-pre-commit-checks.sh [--target-root PATH] [--mode changed|full] \
                                [--base-ref REF] [--fix]

Runs the same checks as local pre-commit hooks in one command:
- forbid tracked .code-checking-ref
- verify executable modes
- run selected linters

Use --fix to apply available auto-fixes.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target-root)
      TARGET_ROOT="$2"
      shift 2
      ;;
    --mode)
      MODE="$2"
      shift 2
      ;;
    --base-ref)
      BASE_REF="$2"
      shift 2
      ;;
    --fix)
      FIX_MODE=1
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

TARGET_ROOT="$(cd "${TARGET_ROOT}" && pwd)"

echo "[pre-commit-checks] target root: ${TARGET_ROOT}"

guard_args=(--target-root "${TARGET_ROOT}")
verify_args=(--target-root "${TARGET_ROOT}")
linter_args=(--target-root "${TARGET_ROOT}" --mode "${MODE}")

if [[ -n "${BASE_REF}" ]]; then
  linter_args+=(--base-ref "${BASE_REF}")
fi

if [[ ${FIX_MODE} -eq 1 ]]; then
  verify_args+=(--fix)
  linter_args+=(--fix)
fi

bash "${LIB_ROOT}/checks/guard-code-checking-ref.sh" "${guard_args[@]}"
bash "${LIB_ROOT}/checks/verify-executable-modes.sh" "${verify_args[@]}"
bash "${LIB_ROOT}/bin/run-linters.sh" "${linter_args[@]}"
