#!/usr/bin/env bash
# Copyright 2026 Hewlett Packard Enterprise Development LP
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

LIB_ROOT="$(cd "${LIB_ROOT}" && pwd)"
TARGET_ROOT="$(cd "${TARGET_ROOT}" && pwd)"
LIB_RELATIVE_PATH=""
if [[ "${LIB_ROOT}" == "${TARGET_ROOT}"/* ]]; then
  LIB_RELATIVE_PATH="${LIB_ROOT#"${TARGET_ROOT}/"}"
fi

get_candidate_paths() {
  if [[ "${MODE}" == "full" ]]; then
    {
      cd "${TARGET_ROOT}"
      git ls-files
      git ls-files --others --exclude-standard
    } | awk 'NF && !seen[$0]++'
    return
  fi

  if [[ -n "${BASE_REF}" ]]; then
    (cd "${TARGET_ROOT}" && git diff --name-only --diff-filter=A "origin/${BASE_REF}...HEAD")
    return
  fi

  local staged_added
  staged_added="$(cd "${TARGET_ROOT}" && git diff --name-only --cached --diff-filter=A)"
  if [[ -n "${staged_added}" ]]; then
    printf '%s\n' "${staged_added}"
    return
  fi

  (cd "${TARGET_ROOT}" && git ls-files --others --exclude-standard)
}

violations=0
while IFS= read -r file_path; do
  [[ -z "${file_path}" ]] && continue
  if [[ -n "${LIB_RELATIVE_PATH}" && "${file_path}" == "${LIB_RELATIVE_PATH}"/* ]]; then
    continue
  fi

  if printf '%s' "${file_path}" | LC_ALL=C grep -q '[^ -~]'; then
    echo "[filename-portability] non-ASCII filename: ${file_path}" >&2
    violations=1
  fi
done < <(get_candidate_paths)

if [[ ${violations} -ne 0 ]]; then
  exit 1
fi

echo "[filename-portability] no portability issues"
