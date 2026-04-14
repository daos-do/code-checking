#!/usr/bin/env bash
# Copyright 2026 Hewlett Packard Enterprise Development LP
set -euo pipefail

LIB_ROOT=""
TARGET_ROOT=""
MODE="changed"
BASE_REF="${GITHUB_BASE_REF:-}"
FIX_MODE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --library-root)
      LIB_ROOT="$2"
      shift 2
      ;;
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
    *)
      echo "Unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

if [[ -z "${LIB_ROOT}" || -z "${TARGET_ROOT}" ]]; then
  echo "--library-root and --target-root are required" >&2
  exit 2
fi

LIB_ROOT="$(cd "${LIB_ROOT}" && pwd)"
TARGET_ROOT="$(cd "${TARGET_ROOT}" && pwd)"
LIB_RELATIVE_PATH=""
if [[ "${LIB_ROOT}" == "${TARGET_ROOT}"/* ]]; then
  LIB_RELATIVE_PATH="${LIB_ROOT#"${TARGET_ROOT}/"}"
fi

get_candidate_files() {
  if [[ "${MODE}" == "full" ]]; then
    (cd "${TARGET_ROOT}" && find . -type f -print | sed 's#^./##')
    return
  fi

  if [[ -n "${BASE_REF}" ]]; then
    (cd "${TARGET_ROOT}" && git diff --name-only --diff-filter=ACMR "origin/${BASE_REF}...HEAD")
    return
  fi

  local staged_files
  staged_files="$(cd "${TARGET_ROOT}" && git diff --name-only --cached --diff-filter=ACMR)"
  if [[ -n "${staged_files}" ]]; then
    printf '%s\n' "${staged_files}"
    return
  fi

  {
    cd "${TARGET_ROOT}"
    git diff --name-only --diff-filter=ACMR
    git ls-files --others --exclude-standard
  } | awk 'NF && !seen[$0]++'
}

has_failures=0
checked_count=0

while IFS= read -r file_path; do
  [[ -z "${file_path}" ]] && continue
  if [[ -n "${LIB_RELATIVE_PATH}" && "${file_path}" == "${LIB_RELATIVE_PATH}"/* ]]; then
    continue
  fi

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

done < <(get_candidate_files)

if [[ ${checked_count} -eq 0 ]]; then
  echo "[text-hygiene] no text files to lint"
  exit 0
fi

if [[ ${has_failures} -ne 0 ]]; then
  exit 1
fi

echo "[text-hygiene] checked ${checked_count} file(s)"
