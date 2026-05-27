#!/usr/bin/env bash
# Copyright 2026 Hewlett Packard Enterprise Development LP
set -euo pipefail

FIX_MODE=0
STAGE_MODE=1
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../../linter-common.sh"

linter_parse_common_args "$@"
for arg in "${LINTER_REMAINING_ARGS[@]}"; do
  case "${arg}" in
    --fix)
      FIX_MODE=1
      ;;
    --no-stage)
      STAGE_MODE=0
      ;;
    *)
      echo "Unknown argument: ${arg}" >&2
      exit 2
      ;;
  esac
done
linter_require_common_args

YEAR_TOKEN='[0-9]{4}(-[0-9]{4})?'
NOTICE_PATTERN="^# Copyright ${YEAR_TOKEN}([[:space:]]*,[[:space:]]*${YEAR_TOKEN})*"
NOTICE_PATTERN+=" Hewlett Packard Enterprise Development LP$"
NOTICE_LINE="# Copyright $(date +%Y) Hewlett Packard Enterprise Development LP"

files_to_check=()
while IFS= read -r file_path; do
  linter_should_skip_candidate_path "${file_path}" && continue

  if linter_is_copyright_candidate "${file_path}"; then
    files_to_check+=("${file_path}")
  fi
done < <(linter_get_candidate_files_acmr)

if [[ ${#files_to_check[@]} -eq 0 ]]; then
  echo "[copyright] no candidate files to lint"
  exit 0
fi

has_failures=0
checked_count=0

for file_path in "${files_to_check[@]}"; do
  absolute_path="${TARGET_ROOT}/${file_path}"
  [[ -f "${absolute_path}" ]] || continue

  checked_count=$((checked_count + 1))

  if head -n 5 "${absolute_path}" | LC_ALL=C grep -Eq "${NOTICE_PATTERN}"; then
    continue
  fi

  if [[ ${FIX_MODE} -eq 1 ]]; then
    tmp_file="$(mktemp)"
    first_line=''
    IFS= read -r first_line < "${absolute_path}" || true

    if [[ "${first_line}" == '#!'* ]]; then
      {
        sed -n '1p' "${absolute_path}"
        printf '%s\n' "${NOTICE_LINE}"
        sed -n '2,$p' "${absolute_path}"
      } > "${tmp_file}"
    else
      {
        printf '%s\n' "${NOTICE_LINE}"
        cat "${absolute_path}"
      } > "${tmp_file}"
    fi

    mv "${tmp_file}" "${absolute_path}"
    if [[ ${STAGE_MODE} -eq 1 ]]; then
      git -C "${TARGET_ROOT}" add -- "${file_path}"
    fi
    echo "[copyright] fixed header: ${file_path}"
  else
    echo "[copyright] missing header: ${file_path}" >&2
    has_failures=1
  fi
done

if [[ ${checked_count} -eq 0 ]]; then
  echo "[copyright] no candidate files to lint"
  exit 0
fi

if [[ ${has_failures} -ne 0 ]]; then
  exit 1
fi

echo "[copyright] checked ${checked_count} file(s)"
