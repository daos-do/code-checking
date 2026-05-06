#!/usr/bin/env bash
# Copyright 2026 Hewlett Packard Enterprise Development LP
set -euo pipefail

TARGET_ROOT=""

usage() {
  cat <<'EOF'
Usage: guard-jenkins-library-pin.sh --target-root PATH

Fails when an active Jenkins shared-library pin is present, such as:
  @Library(value="system-pipeline-lib@my_pr_branch") _

Rationale:
- branch-pinned Jenkins shared library references are for temporary testing
- pinned refs must not be landed in mergeable branches
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target-root)
      TARGET_ROOT="$2"
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

if ! git -C "${TARGET_ROOT}" rev-parse --is-inside-work-tree \
      >/dev/null 2>&1; then
  echo "[jenkins-library-pin-guard] target is not a git working tree:" >&2
  echo "[jenkins-library-pin-guard] ${TARGET_ROOT}" >&2
  exit 2
fi

mapfile -t JENKINS_FILES < <(
  git -C "${TARGET_ROOT}" ls-files -- 'Jenkinsfile*' '*/Jenkinsfile*'
)

if [[ ${#JENKINS_FILES[@]} -eq 0 ]]; then
  echo "[jenkins-library-pin-guard] ok: no Jenkinsfile candidates found"
  exit 0
fi

pin_regex='^[[:space:]]*@Library[[:space:]]*\('
pin_regex+='(value[[:space:]]*=[[:space:]]*)?["'"'"']'
pin_regex+='system-pipeline-lib@[^"'"'"']+["'"'"'][[:space:]]*\)'
pin_regex+='[[:space:]]*_[[:space:]]*($|//.*$)'

guard_failed=0
for rel_path in "${JENKINS_FILES[@]}"; do
  abs_path="${TARGET_ROOT}/${rel_path}"
  [[ -f "${abs_path}" ]] || continue

  if LC_ALL=C grep -nE "${pin_regex}" "${abs_path}" >/dev/null 2>&1; then
    guard_failed=1
    echo "[jenkins-library-pin-guard] blocked: branch pin in ${rel_path}" >&2
    LC_ALL=C grep -nE "${pin_regex}" "${abs_path}" >&2 || true
  fi
done

if [[ ${guard_failed} -ne 0 ]]; then
  echo "[jenkins-library-pin-guard] remove system-pipeline-lib" >&2
  echo "[jenkins-library-pin-guard] @<branch> pins before landing" >&2
  exit 1
fi

echo "[jenkins-library-pin-guard] ok: no active branch pins found"
