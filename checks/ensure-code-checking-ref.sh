#!/usr/bin/env bash
# Copyright 2026 Hewlett Packard Enterprise Development LP
set -euo pipefail

LIB_ROOT=""
TARGET_ROOT=""
DEFAULT_REF="origin/main"

usage() {
  cat <<'EOF'
Usage: ensure-code-checking-ref.sh --library-root PATH --target-root PATH \
                                   [--default-ref REF]

Verifies that the code_checking submodule checkout matches the desired ref.

Normal operation (no code-checking-ref file): uses --default-ref (origin/main).

PR-branch testing override: if <target-root>/code-checking-ref exists, its
first non-empty, non-comment line must be a pull-request ref of the form
"pull/N/head" (e.g. "pull/4/head"). This allows a consumer PR to test against
a not-yet-merged code-checking PR. The file is transient and should not be
committed to the consumer repo's main branch.

This script is non-mutating and fails with instructions when a mismatch is
detected.
EOF
}

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
    --default-ref)
      DEFAULT_REF="$2"
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

if [[ -z "${LIB_ROOT}" || -z "${TARGET_ROOT}" ]]; then
  usage >&2
  exit 2
fi

LIB_ROOT="$(cd "${LIB_ROOT}" && pwd)"
TARGET_ROOT="$(cd "${TARGET_ROOT}" && pwd)"

if [[ "${LIB_ROOT}" == "${TARGET_ROOT}" ]]; then
  echo "[code-checking-ref] library root matches target root; skip ref check"
  exit 0
fi

if [[ "${LIB_ROOT}/" != "${TARGET_ROOT}/"* ]]; then
  echo "[code-checking-ref] library root is outside target root; skip ref check"
  exit 0
fi

REF_FILE="${TARGET_ROOT}/code-checking-ref"
DESIRED_REF="${DEFAULT_REF}"
REF_SOURCE="default-ref"

if [[ -f "${REF_FILE}" ]]; then
  while IFS= read -r line; do
    line="${line%$'\r'}"
    [[ -z "${line//[[:space:]]/}" ]] && continue
    [[ "${line}" =~ ^[[:space:]]*# ]] && continue
    DESIRED_REF="${line}"
    REF_SOURCE="ref-file"
    break
  done < "${REF_FILE}"
fi

# Validate ref-file format: only pull/N/head is supported
if [[ "${REF_SOURCE}" == "ref-file" ]]; then
  if [[ ! "${DESIRED_REF}" =~ ^pull/[0-9]+/head$ ]]; then
    echo "[code-checking-ref] invalid ref in ${REF_FILE}: '${DESIRED_REF}'" >&2
    echo "[code-checking-ref] ref must be of the form pull/N/head (e.g. pull/4/head)" >&2
    exit 1
  fi
  REMOTE_REF="refs/${DESIRED_REF}"
elif [[ "${DESIRED_REF}" == origin/* ]]; then
  REMOTE_REF="refs/heads/${DESIRED_REF#origin/}"
else
  REMOTE_REF="${DESIRED_REF}"
fi

CURRENT_SHA="$(git -C "${LIB_ROOT}" rev-parse HEAD)"

if ! out="$(git -C "${LIB_ROOT}" ls-remote --exit-code origin "${REMOTE_REF}" 2>/dev/null)"; then
  echo "[code-checking-ref] unable to resolve ref '${DESIRED_REF}' from origin" >&2
  echo "[code-checking-ref] ensure network access and that the ref exists" >&2
  exit 1
fi

DESIRED_SHA="$(awk 'NR==1 {print $1}' <<< "${out}")"

if [[ -z "${DESIRED_SHA}" ]]; then
  echo "[code-checking-ref] unable to resolve ref '${DESIRED_REF}' from origin" >&2
  exit 1
fi

if [[ "${CURRENT_SHA}" != "${DESIRED_SHA}" ]]; then
  echo "[code-checking-ref] submodule checkout mismatch" >&2
  echo "[code-checking-ref] desired ref: ${DESIRED_REF}" >&2
  echo "[code-checking-ref] source: ${REF_SOURCE}" >&2
  echo "[code-checking-ref] desired sha: ${DESIRED_SHA}" >&2
  echo "[code-checking-ref] current sha: ${CURRENT_SHA}" >&2
  echo "[code-checking-ref] run the following commands, then rerun checks:" >&2
  echo "  git -C \"${LIB_ROOT}\" fetch origin \"${DESIRED_REF}\"" >&2
  echo "  git -C \"${LIB_ROOT}\" checkout FETCH_HEAD" >&2
  exit 1
fi

echo "[code-checking-ref] verified: ${DESIRED_REF} (${DESIRED_SHA}) from ${REF_SOURCE}"
