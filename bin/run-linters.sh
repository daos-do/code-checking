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
Usage: run-linters.sh [--target-root PATH] [--mode changed|full] \
                      [--base-ref REF] [--fix]

Runs applicable linters for the target repository.

- Library root is derived from this script location.
- Target repository root defaults to the current working directory.
- In a consumer repository, run this from the consumer root via the submodule
  path.
- --fix enables auto-fix for linters that support it.
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

echo "[linters] library root: ${LIB_ROOT}"
echo "[linters] target root: ${TARGET_ROOT}"
echo "[linters] mode: ${MODE}"
if [[ ${FIX_MODE} -eq 1 ]]; then
  echo "[linters] fix mode: enabled"
fi

if [[ ${FIX_MODE} -eq 1 ]]; then
  bash "${LIB_ROOT}/checks/verify-executable-modes.sh" \
    --target-root "${TARGET_ROOT}" \
    --fix
fi

bash "${LIB_ROOT}/checks/ensure-code-checking-ref.sh" \
  --library-root "${LIB_ROOT}" \
  --target-root "${TARGET_ROOT}"

detect_args=(
  --library-root "${LIB_ROOT}"
  --target-root "${TARGET_ROOT}"
  --mode "${MODE}"
)
if [[ -n "${BASE_REF}" ]]; then
  detect_args+=(--base-ref "${BASE_REF}")
fi

mapfile -t REQUIRED_LINTERS < <(
  bash "${LIB_ROOT}/checks/detect-linters.sh" "${detect_args[@]}"
)

if [[ ${#REQUIRED_LINTERS[@]} -eq 0 ]]; then
  echo "[linters] no applicable linters for selected files"
  exit 0
fi

echo "[linters] selected linters: ${REQUIRED_LINTERS[*]}"

bash "${LIB_ROOT}/checks/ensure-linter-tools.sh" "${REQUIRED_LINTERS[@]}"

for linter in "${REQUIRED_LINTERS[@]}"; do
  case "${linter}" in
    shellcheck)
      run_args=(
        --library-root "${LIB_ROOT}"
        --target-root "${TARGET_ROOT}"
        --mode "${MODE}"
      )
      if [[ -n "${BASE_REF}" ]]; then
        run_args+=(--base-ref "${BASE_REF}")
      fi
      bash "${LIB_ROOT}/checks/linters/shellcheck/run.sh" "${run_args[@]}"
      ;;
    codespell)
      run_args=(
        --library-root "${LIB_ROOT}"
        --target-root "${TARGET_ROOT}"
        --mode "${MODE}"
      )
      if [[ -n "${BASE_REF}" ]]; then
        run_args+=(--base-ref "${BASE_REF}")
      fi
      bash "${LIB_ROOT}/checks/linters/codespell/run.sh" "${run_args[@]}"
      ;;
    text-hygiene)
      run_args=(
        --library-root "${LIB_ROOT}"
        --target-root "${TARGET_ROOT}"
        --mode "${MODE}"
      )
      if [[ -n "${BASE_REF}" ]]; then
        run_args+=(--base-ref "${BASE_REF}")
      fi
      if [[ ${FIX_MODE} -eq 1 ]]; then
        run_args+=(--fix)
      fi
      bash "${LIB_ROOT}/checks/linters/text-hygiene/run.sh" "${run_args[@]}"
      ;;
    filename-portability)
      run_args=(
        --library-root "${LIB_ROOT}"
        --target-root "${TARGET_ROOT}"
        --mode "${MODE}"
      )
      if [[ -n "${BASE_REF}" ]]; then
        run_args+=(--base-ref "${BASE_REF}")
      fi
      bash "${LIB_ROOT}/checks/linters/filename-portability/run.sh" "${run_args[@]}"
      ;;
    *)
      echo "Unknown linter selected: ${linter}" >&2
      exit 2
      ;;
  esac
done

echo "[linters] complete"
