#!/usr/bin/env bash
# Copyright 2026 Hewlett Packard Enterprise Development LP

# Shared argument parsing and candidate file selection for shell linters.

LIB_ROOT=""
TARGET_ROOT=""
MODE="changed"
BASE_REF="${GITHUB_BASE_REF:-}"
LIB_RELATIVE_PATH=""
LINTER_REMAINING_ARGS=()

linter_parse_common_args() {
  LIB_ROOT=""
  TARGET_ROOT=""
  MODE="changed"
  BASE_REF="${GITHUB_BASE_REF:-}"
  LINTER_REMAINING_ARGS=()

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
        LINTER_REMAINING_ARGS+=("$1")
        shift
        ;;
    esac
  done
}

linter_require_common_args() {
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
}

linter_fail_on_unknown_args() {
  if [[ ${#LINTER_REMAINING_ARGS[@]} -gt 0 ]]; then
    echo "Unknown argument: ${LINTER_REMAINING_ARGS[0]}" >&2
    exit 2
  fi
}

linter_get_candidate_files_acmr() {
  if [[ "${MODE}" == "full" ]]; then
    # Normalize `find` output to match git path style (no leading `./`).
    (cd "${TARGET_ROOT}" && find . -type f -print | sed 's#^./##')
    return
  fi

  if [[ -n "${BASE_REF}" ]]; then
    (cd "${TARGET_ROOT}" && git diff --name-only \
      --diff-filter=ACMR "origin/${BASE_REF}...HEAD")
    return
  fi

  local staged_files
  staged_files="$(cd "${TARGET_ROOT}" && git diff --name-only \
    --cached --diff-filter=ACMR)"
  if [[ -n "${staged_files}" ]]; then
    printf '%s\n' "${staged_files}"
    return
  fi

  {
    cd "${TARGET_ROOT}" || return
    git diff --name-only --diff-filter=ACMR
    git ls-files --others --exclude-standard
  } | sort -u
}

linter_get_candidate_paths_added() {
  if [[ "${MODE}" == "full" ]]; then
    {
      cd "${TARGET_ROOT}" || return
      git ls-files
      git ls-files --others --exclude-standard
    } | sort -u
    return
  fi

  if [[ -n "${BASE_REF}" ]]; then
    (cd "${TARGET_ROOT}" && git diff --name-only \
      --diff-filter=A "origin/${BASE_REF}...HEAD")
    return
  fi

  local staged_added
  staged_added="$(cd "${TARGET_ROOT}" && git diff --name-only \
    --cached --diff-filter=A)"
  if [[ -n "${staged_added}" ]]; then
    printf '%s\n' "${staged_added}"
    return
  fi

  (cd "${TARGET_ROOT}" && git ls-files --others --exclude-standard)
}

linter_should_skip_candidate_path() {
  local file_path="$1"

  [[ -z "${file_path}" ]] && return 0
  if [[ -n "${LIB_RELATIVE_PATH}" && "${file_path}" == "${LIB_RELATIVE_PATH}"/* ]]; then
    return 0
  fi

  return 1
}

linter_is_shell_script_candidate() {
  local file_path="$1"
  local absolute_path="${TARGET_ROOT}/${file_path}"
  local base_name="${file_path##*/}"
  local first_line=""

  [[ -f "${absolute_path}" ]] || return 1

  if [[ "${file_path}" == *.sh ]]; then
    return 0
  fi

  # Files without an extension may still be shell scripts when they
  # declare a shell interpreter in a shebang line.
  if [[ "${base_name}" == *.* ]]; then
    return 1
  fi

  IFS= read -r first_line < "${absolute_path}" || true
  if printf '%s\n' "${first_line}" | LC_ALL=C grep -Eq \
    '^#![[:space:]]*([^[:space:]]+/)?(env([[:space:]]+-S)?[[:space:]]+)?(bash|sh|dash|ksh|zsh)([[:space:]]|$)'; then
    return 0
  fi

  return 1
}

linter_is_groovy_candidate() {
  local file_path="$1"
  local base_name="${file_path##*/}"
  local absolute_path="${TARGET_ROOT}/${file_path}"

  [[ -f "${absolute_path}" ]] || return 1

  case "${file_path}" in
    *.groovy|*.gradle|Jenkinsfile*)
      return 0
      ;;
  esac

  return 1
}

linter_is_markdown_candidate() {
  local file_path="$1"
  local absolute_path="${TARGET_ROOT}/${file_path}"

  [[ -f "${absolute_path}" ]] || return 1

  case "${file_path}" in
    *.md|*.markdown)
      return 0
      ;;
  esac

  return 1
}
