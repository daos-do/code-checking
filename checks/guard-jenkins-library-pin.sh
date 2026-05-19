#!/usr/bin/env bash
# Copyright 2026 Hewlett Packard Enterprise Development LP
set -euo pipefail

TARGET_ROOT=""

usage() {
  cat <<'EOF'
Usage: guard-jenkins-library-pin.sh --target-root PATH

Fails when an active Jenkins shared-library reference is present, such as:
  @Library("my-shared-lib") _

Rationale:
- live @Library references are for PR/testing workflows only
- @Library references must not be landed in mergeable branches
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

library_regex='@Library[[:space:]]*\('

guard_failed=0
for rel_path in "${JENKINS_FILES[@]}"; do
  abs_path="${TARGET_ROOT}/${rel_path}"
  [[ -f "${abs_path}" ]] || continue

  mapfile -t library_hits < <(
    LC_ALL=C awk -v pattern="${library_regex}" '
      {
        line = $0

        # Ignore single-line comments and block-comment boundaries.
        if (line ~ /^[[:space:]]*\/\//) {
          next
        }
        if (line ~ /^[[:space:]]*\/\*/) {
          in_block_comment = 1
          next
        }
        if (in_block_comment) {
          if (line ~ /\*\//) {
            in_block_comment = 0
          }
          next
        }

        if (line ~ pattern) {
          print NR ":" line
        }
      }
    ' "${abs_path}"
  )

  if [[ ${#library_hits[@]} -gt 0 ]]; then
    guard_failed=1
    echo "[jenkins-library-pin-guard] blocked: active @Library reference in ${rel_path}" >&2
    printf '%s\n' "${library_hits[@]}" >&2
  fi
done

if [[ ${guard_failed} -ne 0 ]]; then
  echo "[jenkins-library-pin-guard] remove active @Library references" >&2
  echo "[jenkins-library-pin-guard] before landing to mergeable branches" >&2
  exit 1
fi

echo "[jenkins-library-pin-guard] ok: no active @Library references found"
