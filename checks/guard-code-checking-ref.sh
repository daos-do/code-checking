#!/usr/bin/env bash
set -euo pipefail

TARGET_ROOT=""
FILE_NAME=".code-checking-ref"

usage() {
  cat <<'EOF'
Usage: guard-code-checking-ref.sh --target-root PATH [--file-name NAME]

Fails if the override file is tracked by git in the target repository.

Rationale:
- local untracked override files are allowed for temporary validation
- tracked override files should be blocked from commits and PRs
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target-root)
      TARGET_ROOT="$2"
      shift 2
      ;;
    --file-name)
      FILE_NAME="$2"
      shift 2
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

if [[ -z "${TARGET_ROOT}" ]]; then
  usage >&2
  exit 2
fi

TARGET_ROOT="$(cd "${TARGET_ROOT}" && pwd)"

if ! git -C "${TARGET_ROOT}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "[code-checking-ref-guard] target is not a git working tree: ${TARGET_ROOT}" >&2
  exit 2
fi

if git -C "${TARGET_ROOT}" ls-files --error-unmatch -- "${FILE_NAME}" >/dev/null 2>&1; then
  mapfile -t STAGED_PATHS < <(
    git -C "${TARGET_ROOT}" diff --cached --name-only --diff-filter=ACMR
  )
  ONLY_OVERRIDE_STAGED=false
  if [[ ${#STAGED_PATHS[@]} -eq 1 && "${STAGED_PATHS[0]}" == "${FILE_NAME}" ]]; then
    ONLY_OVERRIDE_STAGED=true
  fi

  echo "[code-checking-ref-guard] blocked: ${FILE_NAME} is tracked by git" >&2
  echo "[code-checking-ref-guard] keep ${FILE_NAME} untracked for temporary local validation only" >&2
  if [[ "${ONLY_OVERRIDE_STAGED}" == true ]]; then
    echo "[code-checking-ref-guard] only ${FILE_NAME} is staged" >&2
    echo "[code-checking-ref-guard] if this is an intentional non-mergeable test PR, you can commit with: git commit --no-verify" >&2
  fi
  echo "[code-checking-ref-guard] to fix: git -C \"${TARGET_ROOT}\" rm --cached -- \"${FILE_NAME}\"" >&2
  exit 1
fi

echo "[code-checking-ref-guard] ok: ${FILE_NAME} is not tracked"
