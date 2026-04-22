#!/usr/bin/env bash
# Copyright 2026 Hewlett Packard Enterprise Development LP
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../../linter-common.sh"

linter_parse_common_args "$@"
linter_fail_on_unknown_args
linter_require_common_args

if ! command -v shellcheck >/dev/null 2>&1; then
  echo "shellcheck is required but was not found in PATH" >&2
  exit 127
fi

files_to_check=()
while IFS= read -r file_path; do
  linter_should_skip_candidate_path "${file_path}" && continue

  if linter_is_shell_script_candidate "${file_path}"; then
    files_to_check+=("${TARGET_ROOT}/${file_path}")
  fi
done < <(linter_get_candidate_files_acmr)

if [[ ${#files_to_check[@]} -eq 0 ]]; then
  echo "[shellcheck] no shell files to lint"
  exit 0
fi

echo "[shellcheck] linting ${#files_to_check[@]} file(s)"
shellcheck --external-sources "${files_to_check[@]}"
