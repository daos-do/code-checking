#!/usr/bin/env bash
# Copyright 2026 Hewlett Packard Enterprise Development LP
set -euo pipefail

FIX_MODE=0
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../../linter-common.sh"

linter_parse_common_args "$@"
for arg in "${LINTER_REMAINING_ARGS[@]}"; do
  case "${arg}" in
    --fix)
      FIX_MODE=1
      ;;
    *)
      echo "Unknown argument: ${arg}" >&2
      exit 2
      ;;
  esac
done
linter_require_common_args

has_failures=0
checked_count=0

while IFS= read -r file_path; do
  linter_should_skip_candidate_path "${file_path}" && continue

  absolute_path="${TARGET_ROOT}/${file_path}"
  if [[ ! -f "${absolute_path}" ]]; then
    continue
  fi

  if ! LC_ALL=C grep -Iq . "${absolute_path}"; then
    continue
  fi

  checked_count=$((checked_count + 1))

  if grep -nE '[[:blank:]]+$' "${absolute_path}" >/dev/null; then
    if [[ ${FIX_MODE} -eq 1 ]]; then
      sed -i 's/[[:blank:]]\+$//' "${absolute_path}"
      git -C "${TARGET_ROOT}" add -- "${file_path}"
      echo "[text-hygiene] fixed trailing whitespace: ${file_path}" >&2
    else
      echo "[text-hygiene] trailing whitespace: ${file_path}" >&2
      grep -nE '[[:blank:]]+$' "${absolute_path}" >&2 || true
      has_failures=1
    fi
  fi

  # Check for text files that do not have a newline at the end of their
  # last line with content in it.
  if [[ -s "${absolute_path}" ]]; then
    last_byte="$(tail -c 1 "${absolute_path}" | od -An -t u1 | tr -d '[:space:]')"
    if [[ -n "${last_byte}" && "${last_byte}" != "10" ]]; then
      if [[ ${FIX_MODE} -eq 1 ]]; then
        printf '\n' >> "${absolute_path}"
        git -C "${TARGET_ROOT}" add -- "${file_path}"
        echo "[text-hygiene] fixed final newline: ${file_path}" >&2
      else
        echo "[text-hygiene] missing final newline: ${file_path}" >&2
        has_failures=1
      fi
    fi
  fi

 done < <(linter_get_candidate_files_acmr)

if [[ ${checked_count} -eq 0 ]]; then
  echo "[text-hygiene] no text files to lint"
  exit 0
fi

if [[ ${has_failures} -ne 0 ]]; then
  exit 1
fi

echo "[text-hygiene] checked ${checked_count} file(s)"
