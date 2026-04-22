#!/usr/bin/env bash
# Copyright 2026 Hewlett Packard Enterprise Development LP
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../../linter-common.sh"

linter_parse_common_args "$@"
linter_fail_on_unknown_args
linter_require_common_args

violations=0
while IFS= read -r file_path; do
  linter_should_skip_candidate_path "${file_path}" && continue

  if printf '%s' "${file_path}" | LC_ALL=C grep -q '[^ -~]'; then
    echo "[filename-portability] non-ASCII filename: '${file_path}'" >&2
    violations=1
  fi
done < <(linter_get_candidate_paths_added)

if [[ ${violations} -ne 0 ]]; then
  exit 1
fi

echo "[filename-portability] no portability issues"
