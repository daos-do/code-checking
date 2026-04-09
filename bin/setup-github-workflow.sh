#!/usr/bin/env bash
set -euo pipefail

TARGET_ROOT="$(pwd)"
SUBMODULE_PATH="code_checking"
WORKFLOW_RELATIVE_PATH=".github/workflows/basic-source-checks.yml"
MODE="check"

usage() {
  cat <<'EOF'
Usage: setup-github-workflow.sh [--target-root PATH] [--submodule-path PATH] [--apply]

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
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

TARGET_ROOT="$(cd "${TARGET_ROOT}" && pwd)"
WORKFLOW_PATH="${TARGET_ROOT}/${WORKFLOW_RELATIVE_PATH}"

read -r -d '' TEMPLATE <<'EOF' || true
name: basic-source-checks

on:
  pull_request:

jobs:
  basic-source-checks:
    name: Basic Source checks
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v5
        with:
          submodules: recursive
          fetch-depth: 0

      - name: Install dependencies
        run: |
          sudo apt-get update
          sudo apt-get install -y shellcheck

      - name: Resolve code_checking ref
        run: |
          REF="origin/main"
          if [ -f .code-checking-ref ]; then
            REF="$(grep -v '^[[:space:]]*#' .code-checking-ref | sed '/^[[:space:]]*$/d' | head -n 1)"
          fi
          if [ -z "${REF}" ]; then
            REF="origin/main"
          fi
          case "${REF}" in
            refs/*)
              FETCH_REF="${REF}"
              ;;
            origin/*)
              FETCH_REF="refs/heads/${REF#origin/}"
              ;;
            pull/*/head|pull/*/merge)
              FETCH_REF="refs/${REF}"
              ;;
            *)
              FETCH_REF="refs/heads/${REF}"
              ;;
          esac
          git -C ./__CODE_CHECKING_PATH__ fetch origin "${FETCH_REF}"
          git -C ./__CODE_CHECKING_PATH__ checkout FETCH_HEAD
          echo "[workflow] using code_checking ref: ${REF}"

      - name: Block tracked .code-checking-ref
        id: guard_code_checking_ref
        continue-on-error: true
        run: bash ./__CODE_CHECKING_PATH__/checks/guard-code-checking-ref.sh --target-root .

      - name: Verify executable modes
        run: bash ./__CODE_CHECKING_PATH__/checks/verify-executable-modes.sh --target-root .

      - name: Run linters on changed files
        env:
          GITHUB_BASE_REF: ${{ github.base_ref }}
        run: bash ./__CODE_CHECKING_PATH__/bin/run-linters.sh

      - name: Fail if .code-checking-ref is tracked
        if: ${{ always() && steps.guard_code_checking_ref.outcome == 'failure' }}
        run: |
          echo "[workflow] .code-checking-ref was tracked in this change" >&2
          echo "[workflow] keeping the final job status failed after running the remaining checks" >&2
          exit 1

EOF

EXPECTED_CONTENT="${TEMPLATE//__CODE_CHECKING_PATH__/${SUBMODULE_PATH}}"

if [[ "${MODE}" == "check" ]]; then
  if [[ ! -f "${WORKFLOW_PATH}" ]]; then
    echo "[setup-github-workflow] missing workflow: ${WORKFLOW_RELATIVE_PATH}" >&2
    echo "[setup-github-workflow] run with --apply to create/update it" >&2
    exit 1
  fi

  CURRENT_CONTENT="$(cat "${WORKFLOW_PATH}")"
  if [[ "${CURRENT_CONTENT}" != "${EXPECTED_CONTENT}" ]]; then
    echo "[setup-github-workflow] workflow differs from recommended content" >&2
    echo "[setup-github-workflow] file: ${WORKFLOW_RELATIVE_PATH}" >&2
    echo "[setup-github-workflow] run with --apply to update it" >&2
    exit 1
  fi

  echo "[setup-github-workflow] workflow is up to date"
  exit 0
fi

mkdir -p "$(dirname "${WORKFLOW_PATH}")"
printf '%s\n' "${EXPECTED_CONTENT}" > "${WORKFLOW_PATH}"
echo "[setup-github-workflow] wrote ${WORKFLOW_RELATIVE_PATH}"
