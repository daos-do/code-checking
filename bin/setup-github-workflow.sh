#!/usr/bin/env bash
# Copyright 2026 Hewlett Packard Enterprise Development LP
set -euo pipefail

TARGET_ROOT="$(pwd)"
SUBMODULE_PATH="code_checking"
WORKFLOW_RELATIVE_PATH=".github/workflows/basic-source-checks.yml"
MODE="check"

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

# SC2016: single-quoted strings below are intentional YAML literal content,
#         not shell expansions.
# SC1003: trailing backslashes in single-quoted strings are YAML line
#         continuations, not escape attempts.
# shellcheck disable=SC2016,SC1003
build_workflow_yaml() {
  local code_checking_path="$1"

  printf '%s\n' 'name: basic-source-checks'
  printf '%s\n' ''
  printf '%s\n' 'on:'
  printf '%s\n' '  pull_request:'
  printf '%s\n' ''
  printf '%s\n' 'jobs:'
  printf '%s\n' '  basic-source-checks:'
  printf '%s\n' '    name: Basic Source checks'
  printf '%s\n' '    runs-on: ubuntu-latest'
  printf '%s\n' '    steps:'
  printf '%s\n' '      - name: Checkout'
  printf '%s\n' '        uses: actions/checkout@v5'
  printf '%s\n' '        with:'
  printf '%s\n' '          submodules: recursive'
  printf '%s\n' '          fetch-depth: 0'
  printf '%s\n' ''
  printf '%s\n' '      - name: Resolve code_checking ref'
  printf '%s\n' '        run: |'
  printf '%s\n' '          REF="origin/main"'
  printf '%s\n' '          if [ -f code-checking-ref ]; then'
  printf '%s\n' '            REF="$('
  printf '%s\n' "              grep -v '^[[:space:]]*#' code-checking-ref \\"
  printf '%s\n' "                | sed '/^[[:space:]]*$/d' \\"
  printf '%s\n' '                | head -n 1'
  printf '%s\n' '            )"'
  printf '%s\n' '          fi'
  printf '%s\n' '          if [ -z "${REF}" ]; then'
  printf '%s\n' '            REF="origin/main"'
  printf '%s\n' '          fi'
  printf '%s\n' '          case "${REF}" in'
  printf '%s\n' '            refs/*)'
  printf '%s\n' '              FETCH_REF="${REF}"'
  printf '%s\n' '              ;;'
  printf '%s\n' '            origin/*)'
  printf '%s\n' '              FETCH_REF="refs/heads/${REF#origin/}"'
  printf '%s\n' '              ;;'
  printf '%s\n' '            pull/*/head|pull/*/merge)'
  printf '%s\n' '              FETCH_REF="refs/${REF}"'
  printf '%s\n' '              ;;'
  printf '%s\n' '            *)'
  printf '%s\n' '              FETCH_REF="refs/heads/${REF}"'
  printf '%s\n' '              ;;'
  printf '%s\n' '          esac'
  printf '%s\n' "          git -C ./${code_checking_path} fetch origin \"\${FETCH_REF}\""
  printf '%s\n' "          git -C ./${code_checking_path} checkout FETCH_HEAD"
  printf '%s\n' '          echo "[workflow] using code_checking ref: ${REF}"'
  printf '%s\n' ''
  printf '%s\n' '      - name: Install linter tools'
  printf '%s\n' '        env:'
  printf '%s\n' '          GITHUB_BASE_REF: ${{ github.base_ref }}'
  printf '%s\n' '        run: |'
  printf '%s\n' "          ./${code_checking_path}/checks/install-linter-tools.sh \\"
  printf '%s\n' "            --library-root ./${code_checking_path} \\"
  printf '%s\n' '            --target-root . \'
  printf '%s\n' '            --mode changed \'
  printf '%s\n' '            --base-ref "${GITHUB_BASE_REF:-}"'
  printf '%s\n' ''
  printf '%s\n' '      - name: Block tracked code-checking-ref'
  printf '%s\n' '        id: guard_code_checking_ref'
  printf '%s\n' '        continue-on-error: true'
  printf '%s\n' '        run: |'
  printf '%s\n' "          ./${code_checking_path}/checks/guard-code-checking-ref.sh \\"
  printf '%s\n' '            --target-root .'
  printf '%s\n' ''
  printf '%s\n' '      - name: Run linters on changed files'
  printf '%s\n' '        env:'
  printf '%s\n' '          GITHUB_BASE_REF: ${{ github.base_ref }}'
  printf '%s\n' "        run: ./${code_checking_path}/bin/run-linters.sh"
  printf '%s\n' ''
  printf '%s\n' '      - name: Fail if code-checking-ref is tracked'
  printf '%s\n' '        if: >-'
  printf '%s\n' '          ${{ always() &&'
  printf '%s\n' "              steps.guard_code_checking_ref.outcome == 'failure' }}"
  printf '%s\n' '        run: |'
  printf '%s\n' '          echo "[workflow] code-checking-ref was tracked in this change" >&2'
  printf '%s\n' '          echo "[workflow] keeping the final job status failed after" >&2'
  printf '%s\n' '          echo "[workflow] running the remaining checks" >&2'
  printf '%s\n' '          exit 1'
}

EXPECTED_CONTENT="$(build_workflow_yaml "${SUBMODULE_PATH}")"

if [[ "${MODE}" == "check" ]]; then
  if [[ ! -f "${WORKFLOW_PATH}" ]]; then
    printf '%s\n' "[setup-github-workflow] missing workflow: ${WORKFLOW_RELATIVE_PATH}" >&2
    printf '%s\n' "[setup-github-workflow] run with --apply to create it" >&2
    exit 1
  fi

  CURRENT_CONTENT="$(cat "${WORKFLOW_PATH}")"
  if [[ "${CURRENT_CONTENT}" != "${EXPECTED_CONTENT}" ]]; then
    printf '%s\n' "[setup-github-workflow] workflow differs from recommended content" >&2
    printf '%s\n' "[setup-github-workflow] file: ${WORKFLOW_RELATIVE_PATH}" >&2
    printf '%s\n' "[setup-github-workflow] run with --apply to update it" >&2
    exit 1
  fi

  printf '%s\n' "[setup-github-workflow] workflow is up to date"
  exit 0
fi

mkdir -p "$(dirname "${WORKFLOW_PATH}")"
printf '%s\n' "${EXPECTED_CONTENT}" > "${WORKFLOW_PATH}"
printf '%s\n' "[setup-github-workflow] wrote ${WORKFLOW_RELATIVE_PATH}"
