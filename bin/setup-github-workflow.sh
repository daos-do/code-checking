#!/usr/bin/env bash
# Copyright 2026 Hewlett Packard Enterprise Development LP
set -euo pipefail

TARGET_ROOT="$(pwd)"
SUBMODULE_PATH="code_checking"
WORKFLOW_RELATIVE_PATH=".github/workflows/basic-source-checks.yml"
MODE="check"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

escape_sed_replacement() {
  printf '%s' "$1" | sed -e 's/[&|]/\\&/g'
}

render_workflow_yaml() {
  local code_checking_path="$1"
  local template_path="${SCRIPT_DIR}/../checks/workflow_d/"
  template_path+="basic-source-checks.template.yml"

  if [[ ! -f "${template_path}" ]]; then
    printf '%s\n' "[setup-github-workflow] missing template:" \
      "${template_path}" >&2
    return 1
  fi

  local escaped_code_checking_path=""
  escaped_code_checking_path="$(escape_sed_replacement "${code_checking_path}")"
  sed "s|__CODE_CHECKING_PATH__|${escaped_code_checking_path}|g" \
    "${template_path}"
}

usage() {
  cat <<'EOF'
Usage: setup-github-workflow.sh [--target-root PATH] \
                                [--submodule-path PATH] [--apply]

Checks or writes the recommended GitHub workflow that runs shared linters from
this repository when used as a submodule.

Defaults:
- target root: current directory
- submodule path: code_checking
- mode: check (non-mutating)

Use --apply to write/update the workflow file.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target-root)
      TARGET_ROOT="$2"
      shift 2
      ;;
    --submodule-path)
      SUBMODULE_PATH="$2"
      shift 2
      ;;
    --apply)
      MODE="apply"
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      printf '%s\n' "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

TARGET_ROOT="$(cd "${TARGET_ROOT}" && pwd)"
WORKFLOW_PATH="${TARGET_ROOT}/${WORKFLOW_RELATIVE_PATH}"
TMP_EXPECTED="$(mktemp)"
trap 'rm -f "${TMP_EXPECTED}"' EXIT
render_workflow_yaml "${SUBMODULE_PATH}" > "${TMP_EXPECTED}"

if [[ "${MODE}" == "check" ]]; then
  if [[ ! -f "${WORKFLOW_PATH}" ]]; then
    printf '%s\n' "[setup-github-workflow] missing workflow:" \
      "${WORKFLOW_RELATIVE_PATH}" >&2
    printf '%s\n' "[setup-github-workflow] run with --apply to create it" >&2
    exit 1
  fi

  if ! cmp -s "${WORKFLOW_PATH}" "${TMP_EXPECTED}"; then
    printf '%s\n' "[setup-github-workflow] workflow differs from" \
      "recommended content" >&2
    printf '%s\n' "[setup-github-workflow] file: ${WORKFLOW_RELATIVE_PATH}" >&2
    printf '%s\n' "[setup-github-workflow] run with --apply to update it" >&2
    exit 1
  fi

  printf '%s\n' "[setup-github-workflow] workflow is up to date"
  exit 0
fi

mkdir -p "$(dirname "${WORKFLOW_PATH}")"
cp "${TMP_EXPECTED}" "${WORKFLOW_PATH}"
printf '%s\n' "[setup-github-workflow] wrote ${WORKFLOW_RELATIVE_PATH}"
