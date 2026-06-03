#!/usr/bin/env bash
# Copyright 2026 Hewlett Packard Enterprise Development LP
set -euo pipefail

TARGET_ROOT="$(pwd)"
SUBMODULE_PATH="code_checking"
MODE="check"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

escape_sed_replacement() {
  printf '%s' "$1" | sed -e 's/[&|]/\\&/g'
}

render_workflow_yaml() {
  local code_checking_path="$1"
  local template_name="$2"
  local template_path="${SCRIPT_DIR}/../checks/workflow_d/"
  template_path+="${template_name}"

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

Checks or writes the recommended GitHub workflows for consumer repositories.

Defaults:
- target root: current directory
- submodule path: code_checking
- mode: check (non-mutating)

Use --apply to write/update workflow files.
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

WORKFLOW_TARGETS=(
  ".github/workflows/basic-source-checks.yml:basic-source-checks.template.yml"
  ".github/workflows/dco-signoff.yml:dco-signoff.template.yml"
)

for workflow_target in "${WORKFLOW_TARGETS[@]}"; do
  workflow_relative_path="${workflow_target%%:*}"
  template_name="${workflow_target#*:}"
  workflow_path="${TARGET_ROOT}/${workflow_relative_path}"
  tmp_expected="$(mktemp)"

  render_workflow_yaml "${SUBMODULE_PATH}" "${template_name}" > "${tmp_expected}"

  if [[ "${MODE}" == "check" ]]; then
    if [[ ! -f "${workflow_path}" ]]; then
      printf '%s\n' "[setup-github-workflow] missing workflow:" \
        "${workflow_relative_path}" >&2
      printf '%s\n' "[setup-github-workflow] run with --apply to create it" >&2
      rm -f "${tmp_expected}"
      exit 1
    fi

    if ! cmp -s "${workflow_path}" "${tmp_expected}"; then
      printf '%s\n' "[setup-github-workflow] workflow differs from" \
        "recommended content" >&2
      printf '%s\n' "[setup-github-workflow] file: ${workflow_relative_path}" >&2
      printf '%s\n' "[setup-github-workflow] run with --apply to update it" >&2
      rm -f "${tmp_expected}"
      exit 1
    fi

    rm -f "${tmp_expected}"
    continue
  fi

  mkdir -p "$(dirname "${workflow_path}")"
  cp "${tmp_expected}" "${workflow_path}"
  rm -f "${tmp_expected}"
  printf '%s\n' "[setup-github-workflow] wrote ${workflow_relative_path}"
done

if [[ "${MODE}" == "check" ]]; then
  printf '%s\n' "[setup-github-workflow] workflows are up to date"
fi
