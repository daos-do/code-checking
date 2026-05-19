#!/usr/bin/env bash
# Copyright 2026 Hewlett Packard Enterprise Development LP
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TARGET_ROOT="$(pwd)"
MODE="changed"
BASE_REF="${GITHUB_BASE_REF:-}"
FIX_MODE=0
STAGE_MODE=1

usage() {
  cat <<'EOF'
Usage: run-linters.sh [--target-root PATH] [--mode changed|full] \
                      [--base-ref REF] [--fix] [--no-stage]

Runs applicable linters for the target repository.

- Library root is derived from this script location.
- Target repository root defaults to the current working directory.
- In a consumer repository, run this from the consumer root via the submodule
  path.
- --fix enables auto-fix for linters that support it.
- --no-stage suppresses automatic git staging of fixed files.
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
    --no-stage)
      STAGE_MODE=0
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
  if [[ ${STAGE_MODE} -eq 0 ]]; then
    echo "[linters] staging: disabled"
  fi
fi

verify_args=(--target-root "${TARGET_ROOT}")
if [[ ${FIX_MODE} -eq 1 ]]; then
  verify_args+=(--fix)
  if [[ ${STAGE_MODE} -eq 0 ]]; then
    verify_args+=(--no-stage)
  fi
fi
"${LIB_ROOT}/checks/verify-executable-modes.sh" "${verify_args[@]}"

"${LIB_ROOT}/checks/ensure-code-checking-ref.sh" \
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
  "${LIB_ROOT}/checks/detect-linters.sh" "${detect_args[@]}"
)

if [[ ${#REQUIRED_LINTERS[@]} -eq 0 ]]; then
  echo "[linters] no applicable linters for selected files"
  exit 0
fi

echo "[linters] selected linters: ${REQUIRED_LINTERS[*]}"

"${LIB_ROOT}/checks/install-linter-tools.sh" "${detect_args[@]}"

run_args_common=(
  --library-root "${LIB_ROOT}"
  --target-root "${TARGET_ROOT}"
  --mode "${MODE}"
)
if [[ -n "${BASE_REF}" ]]; then
  run_args_common+=(--base-ref "${BASE_REF}")
fi

failed_linters=()

for linter in "${REQUIRED_LINTERS[@]}"; do
  linter_rc=0
  case "${linter}" in
    shellcheck)
      run_args=("${run_args_common[@]}")
      if ! "${LIB_ROOT}/checks/linters/shellcheck/run.sh" "${run_args[@]}"; then
        linter_rc=$?
      fi
      ;;
    groovylint)
      run_args=("${run_args_common[@]}")
      if ! "${LIB_ROOT}/checks/linters/groovylint/run.sh" "${run_args[@]}"; then
        linter_rc=$?
      fi
      ;;
    markdownlint)
      run_args=("${run_args_common[@]}")
      if ! "${LIB_ROOT}/checks/linters/markdownlint/run.sh" "${run_args[@]}";
      then
        linter_rc=$?
      fi
      ;;
    yamllint)
      run_args=("${run_args_common[@]}")
      if ! "${LIB_ROOT}/checks/linters/yamllint/run.sh" "${run_args[@]}"; then
        linter_rc=$?
      fi
      ;;
    python)
      run_args=("${run_args_common[@]}")
      if ! "${LIB_ROOT}/checks/linters/python/run.sh" "${run_args[@]}"; then
        linter_rc=$?
      fi
      ;;
    copyright)
      run_args=("${run_args_common[@]}")
      if [[ ${FIX_MODE} -eq 1 ]]; then
        run_args+=(--fix)
        if [[ ${STAGE_MODE} -eq 0 ]]; then
          run_args+=(--no-stage)
        fi
      fi
      if ! "${LIB_ROOT}/checks/linters/copyright/run.sh" "${run_args[@]}"; then
        linter_rc=$?
      fi
      ;;
    codespell)
      run_args=("${run_args_common[@]}")
      if ! "${LIB_ROOT}/checks/linters/codespell/run.sh" "${run_args[@]}"; then
        linter_rc=$?
      fi
      ;;
    text-hygiene)
      run_args=("${run_args_common[@]}")
      if [[ ${FIX_MODE} -eq 1 ]]; then
        run_args+=(--fix)
        if [[ ${STAGE_MODE} -eq 0 ]]; then
          run_args+=(--no-stage)
        fi
      fi
      if ! "${LIB_ROOT}/checks/linters/text-hygiene/run.sh" "${run_args[@]}";
      then
        linter_rc=$?
      fi
      ;;
    filename-portability)
      run_args=("${run_args_common[@]}")
      if ! "${LIB_ROOT}/checks/linters/filename-portability/run.sh" "${run_args[@]}";
      then
        linter_rc=$?
      fi
      ;;
    *)
      echo "Unknown linter selected: ${linter}" >&2
      exit 2
      ;;
  esac

  if [[ ${linter_rc} -ne 0 ]]; then
    failed_linters+=("${linter}")
  fi
done

if [[ ${#failed_linters[@]} -gt 0 ]]; then
  echo "[linters] failed linters: ${failed_linters[*]}" >&2
  exit 1
fi

echo "[linters] complete"
