#!/usr/bin/env bash
set -euo pipefail

LIB_ROOT=""
TARGET_ROOT=""
MODE="changed"
BASE_REF="${GITHUB_BASE_REF:-}"

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

if ! command -v shellcheck >/dev/null 2>&1; then
  echo "shellcheck is required but was not found in PATH" >&2
  exit 127
fi

LIB_ROOT="$(cd "${LIB_ROOT}" && pwd)"
TARGET_ROOT="$(cd "${TARGET_ROOT}" && pwd)"
LIB_RELATIVE_PATH=""
if [[ "${LIB_ROOT}" == "${TARGET_ROOT}"/* ]]; then
  LIB_RELATIVE_PATH="${LIB_ROOT#"${TARGET_ROOT}/"}"
fi

get_candidate_files() {
  if [[ "${MODE}" == "full" ]]; then
    (cd "${TARGET_ROOT}" && find . -type f -name '*.sh' -print | sed 's#^./##')
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

files_to_check=()
while IFS= read -r file_path; do
  [[ -z "${file_path}" ]] && continue
  if [[ -n "${LIB_RELATIVE_PATH}" && "${file_path}" == "${LIB_RELATIVE_PATH}"/* ]]; then
    continue
  fi
  case "${file_path}" in
    *.sh)
      if [[ -f "${TARGET_ROOT}/${file_path}" ]]; then
        files_to_check+=("${TARGET_ROOT}/${file_path}")
      fi
      ;;
  esac
done < <(get_candidate_files)

if [[ ${#files_to_check[@]} -eq 0 ]]; then
  echo "[shellcheck] no shell files to lint"
  exit 0
fi

echo "[shellcheck] linting ${#files_to_check[@]} file(s)"
shellcheck --external-sources "${files_to_check[@]}"