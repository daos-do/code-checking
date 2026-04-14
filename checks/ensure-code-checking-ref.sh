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
Desired ref comes from <target-root>/.code-checking-ref (first non-empty,
non-comment line). When the file is missing, desired ref is the submodule
git link recorded in the consumer repository HEAD commit.

If neither source can be resolved, falls back to --default-ref (origin/main).

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

REF_FILE="${TARGET_ROOT}/.code-checking-ref"
DESIRED_REF="${DEFAULT_REF}"
REF_SOURCE="default-ref"
LIB_RELATIVE_PATH="${LIB_ROOT#"${TARGET_ROOT}/"}"

if [[ "${LIB_RELATIVE_PATH}" == "${LIB_ROOT}" ]]; then
  echo "[code-checking-ref] unable to determine submodule path; skip ref check"
  exit 0
fi

if [[ ! -f "${REF_FILE}" ]]; then
  if git -C "${TARGET_ROOT}" rev-parse --verify HEAD >/dev/null 2>&1; then
    GIT_LINK_SHA="$(
      git -C "${TARGET_ROOT}" ls-tree HEAD \
        -- "${LIB_RELATIVE_PATH}" 2>/dev/null \
        | awk '$2 == "commit" { print $3; exit }'
    )"
    if [[ -n "${GIT_LINK_SHA}" ]]; then
      DESIRED_REF="${GIT_LINK_SHA}"
      REF_SOURCE="consumer-git-link"
    fi
  fi
fi

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

CURRENT_SHA="$(git -C "${LIB_ROOT}" rev-parse HEAD)"
DESIRED_SHA=""
RESOLVED_FROM=""

is_sha_ref=false
if [[ "${DESIRED_REF}" =~ ^[0-9a-fA-F]{7,40}$ ]]; then
  is_sha_ref=true
fi

if [[ "${is_sha_ref}" == true ]]; then
  DESIRED_SHA="${DESIRED_REF}"
  RESOLVED_FROM="commit-sha"
else
  declare -a candidates=()
  if [[ "${DESIRED_REF}" == refs/* ]]; then
    candidates+=("${DESIRED_REF}")
  elif [[ "${DESIRED_REF}" == origin/* ]]; then
    branch="${DESIRED_REF#origin/}"
    candidates+=("refs/heads/${branch}" "${branch}")
  elif [[ "${DESIRED_REF}" == pull/*/head || \
          "${DESIRED_REF}" == pull/*/merge ]]; then
    candidates+=("refs/${DESIRED_REF}" "${DESIRED_REF}")
  else
    candidates+=("refs/heads/${DESIRED_REF}" "${DESIRED_REF}")
  fi

  for candidate in "${candidates[@]}"; do
    if out="$(
      git -C "${LIB_ROOT}" ls-remote --exit-code origin "${candidate}" \
        2>/dev/null
    )"; then
      DESIRED_SHA="$(awk 'NR==1 {print $1}' <<< "${out}")"
      RESOLVED_FROM="${candidate}"
      [[ -n "${DESIRED_SHA}" ]] && break
    fi
  done
fi

if [[ -z "${DESIRED_SHA}" ]]; then
  echo "[code-checking-ref] unable to resolve desired ref" \
    "'${DESIRED_REF}' from origin" >&2
  echo "[code-checking-ref] set .code-checking-ref to a valid ref" \
    "or ensure network access" >&2
  exit 1
fi

if [[ "${CURRENT_SHA}" != "${DESIRED_SHA}" ]]; then
  echo "[code-checking-ref] submodule checkout mismatch" >&2
  echo "[code-checking-ref] desired ref: ${DESIRED_REF} (${RESOLVED_FROM})" >&2
  echo "[code-checking-ref] source: ${REF_SOURCE}" >&2
  echo "[code-checking-ref] desired sha: ${DESIRED_SHA}" >&2
  echo "[code-checking-ref] current sha: ${CURRENT_SHA}" >&2
  echo "[code-checking-ref] run the following commands, then rerun checks:" >&2
  if [[ "${REF_SOURCE}" == "consumer-git-link" ]]; then
    echo "  git -C \"${TARGET_ROOT}\" submodule update --init" \
      "--recursive -- \"${LIB_RELATIVE_PATH}\"" >&2
  else
    echo "  git -C \"${LIB_ROOT}\" fetch origin \"${DESIRED_REF}\"" >&2
  fi
  if [[ "${REF_SOURCE}" != "consumer-git-link" && \
      ( "${DESIRED_REF}" == origin/* || \
        "${DESIRED_REF}" == refs/* || \
        "${DESIRED_REF}" == pull/*/* ) ]]; then
    echo "  git -C \"${LIB_ROOT}\" checkout FETCH_HEAD" >&2
  elif [[ "${REF_SOURCE}" != "consumer-git-link" ]]; then
    echo "  git -C \"${LIB_ROOT}\" checkout \"${DESIRED_REF}\"" >&2
  fi
  exit 1
fi

echo "[code-checking-ref] verified: ${DESIRED_REF} (${DESIRED_SHA})" \
  "from ${REF_SOURCE}"
