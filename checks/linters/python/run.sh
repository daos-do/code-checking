#!/usr/bin/env bash
# Copyright 2026 Hewlett Packard Enterprise Development LP
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../../linter-common.sh"

linter_parse_common_args "$@"
linter_fail_on_unknown_args
linter_require_common_args

if ! command -v flake8 >/dev/null 2>&1; then
  echo "flake8 is required but was not found in PATH" >&2
  exit 127
fi
if ! command -v pylint >/dev/null 2>&1; then
  echo "pylint is required but was not found in PATH" >&2
  exit 127
fi

files_to_check=()
while IFS= read -r file_path; do
  linter_should_skip_candidate_path "${file_path}" && continue

  if linter_is_python_candidate "${file_path}"; then
    files_to_check+=("${TARGET_ROOT}/${file_path}")
  fi
done < <(linter_get_candidate_files_acmr)

if [[ ${#files_to_check[@]} -eq 0 ]]; then
  echo "[python] no Python files to lint"
  exit 0
fi

echo "[python] linting ${#files_to_check[@]} file(s)"

flake8_rc=0
pylint_rc=0

if ! flake8 "${files_to_check[@]}"; then
  flake8_rc=$?
fi

if ! pylint "${files_to_check[@]}"; then
  pylint_rc=$?
fi

if [[ ${flake8_rc} -ne 0 || ${pylint_rc} -ne 0 ]]; then
  exit 1
fi
