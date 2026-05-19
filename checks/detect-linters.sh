#!/usr/bin/env bash
# Copyright 2026 Hewlett Packard Enterprise Development LP
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/linter-common.sh"

linter_parse_common_args "$@"
linter_fail_on_unknown_args
linter_require_common_args

shellcheck_needed=0
groovylint_needed=0
markdownlint_needed=0
python_needed=0
codespell_needed=0
text_hygiene_needed=0
filename_portability_needed=0
while IFS= read -r file_path; do
  linter_should_skip_candidate_path "${file_path}" && continue

  codespell_needed=1
  text_hygiene_needed=1
  filename_portability_needed=1

  if linter_is_shell_script_candidate "${file_path}"; then
    shellcheck_needed=1
  fi

  if linter_is_groovy_candidate "${file_path}"; then
    groovylint_needed=1
  fi

  if linter_is_markdown_candidate "${file_path}"; then
    markdownlint_needed=1
  fi

  if linter_is_python_candidate "${file_path}"; then
    python_needed=1
  fi
done < <(linter_get_candidate_files_acmr)

if [[ ${shellcheck_needed} -eq 1 ]]; then
  echo 'shellcheck'
fi
if [[ ${groovylint_needed} -eq 1 ]]; then
  echo 'groovylint'
fi
if [[ ${markdownlint_needed} -eq 1 ]]; then
  echo 'markdownlint'
fi
if [[ ${python_needed} -eq 1 ]]; then
  echo 'python'
fi
if [[ ${codespell_needed} -eq 1 ]]; then
  echo 'codespell'
fi
if [[ ${text_hygiene_needed} -eq 1 ]]; then
  echo 'text-hygiene'
fi
if [[ ${filename_portability_needed} -eq 1 ]]; then
  echo 'filename-portability'
fi
