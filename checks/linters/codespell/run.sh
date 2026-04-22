#!/usr/bin/env bash
# Copyright 2026 Hewlett Packard Enterprise Development LP
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../../linter-common.sh"

linter_parse_common_args "$@"
linter_fail_on_unknown_args
linter_require_common_args

if ! command -v codespell >/dev/null 2>&1; then
  echo "codespell is required but was not found in PATH" >&2
  exit 127
fi

files_to_check=()
while IFS= read -r file_path; do
  linter_should_skip_candidate_path "${file_path}" && continue

  absolute_path="${TARGET_ROOT}/${file_path}"
  [[ -f "${absolute_path}" ]] || continue

  # Skip binaries to keep codespell focused on textual content.
  if ! LC_ALL=C grep -Iq . "${absolute_path}"; then
    continue
  fi

  files_to_check+=("${absolute_path}")
done < <(linter_get_candidate_files_acmr)

if [[ ${#files_to_check[@]} -eq 0 ]]; then
  echo "[codespell] no text files to lint"
  exit 0
fi

echo "[codespell] linting ${#files_to_check[@]} file(s)"
codespell --check-filenames --quiet-level 2 -- "${files_to_check[@]}"
