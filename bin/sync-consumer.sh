#!/usr/bin/env bash
# Copyright 2026 Hewlett Packard Enterprise Development LP
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TARGET_ROOT="$(pwd)"
DEFAULT_REF="origin/main"
SUBMODULE_PATH="code_checking"
REFRESH_WORKFLOW=true
REFRESH_PRE_COMMIT=true
UPDATE_README=true

trim_trailing_blank_lines() {
  local file_path="$1"
  local trimmed_file
  trimmed_file="$(mktemp)"

  awk '
    { lines[NR] = $0 }
    /^[[:space:]]*$/ { next }
    { last_nonblank = NR }
    END {
      for (i = 1; i <= last_nonblank; i++) {
        print lines[i]
      }
    }
  ' "${file_path}" > "${trimmed_file}"

  mv "${trimmed_file}" "${file_path}"
}

usage() {
  cat <<'EOF'
Usage: sync-consumer.sh [--target-root PATH] [--submodule-path PATH]
                        [--default-ref REF] [--skip-workflow]
                        [--skip-pre-commit] [--skip-readme]

Synchronizes a consumer repository to the desired code_checking ref from
code-checking-ref (or origin/main by default), refreshes the recommended
GitHub workflow, and refreshes local pre-commit hook installation when the
consumer repository already uses pre-commit.

By default this appends or refreshes a managed section in the consumer
README.md with links to code_checking documentation.
Use --skip-readme to disable README updates.
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
    --default-ref)
      DEFAULT_REF="$2"
      shift 2
      ;;
    --skip-workflow)
      REFRESH_WORKFLOW=false
      shift
      ;;
    --skip-pre-commit)
      REFRESH_PRE_COMMIT=false
      shift
      ;;
    --skip-readme)
      UPDATE_README=false
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

if ! git -C "${TARGET_ROOT}" rev-parse --is-inside-work-tree >/dev/null 2>&1
then
  echo "[sync-consumer] target is not a git repository: ${TARGET_ROOT}" >&2
  exit 2
fi

if [[ "${LIB_ROOT}" == "${TARGET_ROOT}" ]]; then
  echo "[sync-consumer] target root is the code_checking repository" >&2
  echo "[sync-consumer] run this from a consumer repository that" >&2
  echo "[sync-consumer] vendors code_checking as a submodule" >&2
  exit 2
fi

if [[ "${LIB_ROOT}/" != "${TARGET_ROOT}/"* ]]; then
  echo "[sync-consumer] library root is outside target root: ${LIB_ROOT}" >&2
  exit 2
fi

inferred_path="${LIB_ROOT#"${TARGET_ROOT}/"}"
SUBMODULE_PATH="${inferred_path}"

# The consumer may override the desired code_checking ref here; this is
# separate from the currently checked-out submodule commit.
# This is normally used only for testing pull requests or specific refs
# of the submodule and should never be present in a pull requests at the
# time that it is landed.
REF_FILE="${TARGET_ROOT}/code-checking-ref"
DESIRED_REF="${DEFAULT_REF}"

if [[ -f "${REF_FILE}" ]]; then
  while IFS= read -r line; do
    line="${line%$'\r'}"
    [[ -z "${line//[[:space:]]/}" ]] && continue
    [[ "${line}" =~ ^[[:space:]]*# ]] && continue
    DESIRED_REF="${line}"
    break
  done < "${REF_FILE}"
fi

resolve_ref() {
  local desired_ref="$1"
  local desired_sha=""
  local resolved_from=""

  if [[ "${desired_ref}" =~ ^[0-9a-fA-F]{7,40}$ ]]; then
    printf '%s\n%s\n' "${desired_ref}" "commit-sha"
    return 0
  fi

  local -a candidates=()
  if [[ "${desired_ref}" == refs/* ]]; then
    candidates+=("${desired_ref}")
  elif [[ "${desired_ref}" == origin/* ]]; then
    local branch="${desired_ref#origin/}"
    candidates+=("refs/heads/${branch}" "${branch}")
  elif [[ "${desired_ref}" == pull/*/head || "${desired_ref}" == pull/*/merge ]]
  then
    candidates+=("refs/${desired_ref}" "${desired_ref}")
  else
    candidates+=("refs/heads/${desired_ref}" "${desired_ref}")
  fi

  local candidate=""
  local out=""
  for candidate in "${candidates[@]}"; do
    if out="$(git -C "${LIB_ROOT}" ls-remote --exit-code \
      origin "${candidate}" 2>/dev/null)"
    then
      desired_sha="$(awk 'NR==1 {print $1}' <<< "${out}")"
      resolved_from="${candidate}"
      [[ -n "${desired_sha}" ]] && break
    fi
  done

  if [[ -z "${desired_sha}" ]]; then
    return 1
  fi

  printf '%s\n%s\n' "${desired_sha}" "${resolved_from}"
}

mapfile -t resolved_info < <(resolve_ref "${DESIRED_REF}")

if [[ ${#resolved_info[@]} -lt 2 ]] || [[ -z "${resolved_info[0]}" ]]; then
  echo "[sync-consumer] unable to resolve ref '${DESIRED_REF}'" >&2
  echo "[sync-consumer] from origin" >&2
  exit 1
fi

DESIRED_SHA="${resolved_info[0]}"
RESOLVED_FROM="${resolved_info[1]}"
CURRENT_SHA="$(git -C "${LIB_ROOT}" rev-parse HEAD)"

if [[ "${CURRENT_SHA}" != "${DESIRED_SHA}" ]]; then
  echo "[sync-consumer] syncing ${SUBMODULE_PATH}" \
    "to ${DESIRED_REF} (${RESOLVED_FROM})"
  if [[ "${DESIRED_REF}" =~ ^[0-9a-fA-F]{7,40}$ ]]; then
    git -C "${LIB_ROOT}" fetch origin "${DESIRED_REF}"
    git -C "${LIB_ROOT}" checkout "${DESIRED_REF}"
  else
    git -C "${LIB_ROOT}" fetch origin "${RESOLVED_FROM}"
    git -C "${LIB_ROOT}" checkout FETCH_HEAD
  fi
else
  echo "[sync-consumer] ${SUBMODULE_PATH} matches" \
    "${DESIRED_REF} (${CURRENT_SHA:0:12})"
fi

if [[ "${REFRESH_WORKFLOW}" == true ]]; then
  "${LIB_ROOT}/bin/setup-github-workflow.sh" \
    --target-root "${TARGET_ROOT}" \
    --submodule-path "${SUBMODULE_PATH}" \
    --apply
fi

if [[ "${REFRESH_PRE_COMMIT}" == true ]]; then
  if [[ -f "${TARGET_ROOT}/.pre-commit-config.yaml" ]]; then
    if command -v pre-commit >/dev/null 2>&1; then
      echo "[sync-consumer] refreshing pre-commit hooks in ${TARGET_ROOT}"
      (
        cd "${TARGET_ROOT}"
        pre-commit install --install-hooks
      )
    else
      echo "[sync-consumer] pre-commit not installed; skipping hook refresh" >&2
    fi
  else
    echo "[sync-consumer] no .pre-commit-config.yaml in target" >&2
    echo "[sync-consumer] root; skipping hook refresh" >&2
  fi
fi

if [[ "${UPDATE_README}" == true ]]; then
  README_PATH="${TARGET_ROOT}/README.md"
  BEGIN_MARKER='<!-- BEGIN code_checking submodule links -->'
  END_MARKER='<!-- END code_checking submodule links -->'
  README_BLOCK="${BEGIN_MARKER}
## Shared Checks Submodule

This repository uses the shared \`code_checking\` submodule.

- Framework documentation: [code_checking README](./${SUBMODULE_PATH}/README.md)
- Integration guide:
  [code_checking integration](./${SUBMODULE_PATH}/docs/integration.md)

${END_MARKER}"

  if [[ ! -f "${README_PATH}" ]]; then
    echo "[sync-consumer] README.md not found; skipping README update" >&2
  else
    tmp_file="$(mktemp)"
    if grep -qF "${BEGIN_MARKER}" "${README_PATH}"; then
      awk -v begin="${BEGIN_MARKER}" -v end="${END_MARKER}" '
        $0 == begin { in_block = 1; next }
        $0 == end { in_block = 0; next }
        !in_block { print }
      ' "${README_PATH}" > "${tmp_file}"
      trim_trailing_blank_lines "${tmp_file}"
      printf '\n%s\n' "${README_BLOCK}" >> "${tmp_file}"
      mv "${tmp_file}" "${README_PATH}"
      echo "[sync-consumer] refreshed README managed section"
    else
      cp "${README_PATH}" "${tmp_file}"
      trim_trailing_blank_lines "${tmp_file}"
      printf '\n%s\n' "${README_BLOCK}" >> "${tmp_file}"
      mv "${tmp_file}" "${README_PATH}"
      echo "[sync-consumer] appended README managed section"
    fi
  fi
fi

# These baseline files are copied only when missing to bootstrap consumer repos.
# We intentionally do not use symlinks because consumer repos may need to tailor
# these files over time, and symlink behavior is inconsistent across platforms
# and git configurations (especially on Windows).
if [[ ! -f "${TARGET_ROOT}/.gitignore" ]]; then
  GITIGNORE_BASELINE="${LIB_ROOT}/.gitignore"
  if [[ -f "${GITIGNORE_BASELINE}" ]]; then
    cp "${GITIGNORE_BASELINE}" "${TARGET_ROOT}/.gitignore"
    echo "[sync-consumer] created .gitignore from code_checking baseline"
  else
    echo "[sync-consumer] baseline not found: ${GITIGNORE_BASELINE}" >&2
  fi
fi

if [[ ! -f "${TARGET_ROOT}/cspell.config.yaml" ]]; then
  # cspell (VS Code extension/CLI) uses cspell.config.yaml and
  # vscode-project-words.txt. codespell is a separate linter with its own
  # dictionary logic and does not consume these cspell files.
  CSPELL_CONFIG_BASELINE="${LIB_ROOT}/cspell.config.yaml"
  if [[ -f "${CSPELL_CONFIG_BASELINE}" ]]; then
    cp "${CSPELL_CONFIG_BASELINE}" "${TARGET_ROOT}/cspell.config.yaml"
    echo "[sync-consumer] created cspell.config.yaml" \
      "from code_checking baseline"
  else
    echo "[sync-consumer] baseline not found: ${CSPELL_CONFIG_BASELINE}" >&2
  fi
fi

if [[ ! -f "${TARGET_ROOT}/.yamllint" ]]; then
  YAMLLINT_BASELINE="${LIB_ROOT}/.yamllint"
  if [[ -f "${YAMLLINT_BASELINE}" ]]; then
    cp "${YAMLLINT_BASELINE}" "${TARGET_ROOT}/.yamllint"
    echo "[sync-consumer] created .yamllint from code_checking baseline"
  else
    echo "[sync-consumer] baseline not found: ${YAMLLINT_BASELINE}" >&2
  fi
fi

if [[ ! -f "${TARGET_ROOT}/vscode-project-words.txt" ]]; then
  CSPELL_WORDS_BASELINE="${LIB_ROOT}/vscode-project-words.txt"
  if [[ -f "${CSPELL_WORDS_BASELINE}" ]]; then
    cp "${CSPELL_WORDS_BASELINE}" "${TARGET_ROOT}/vscode-project-words.txt"
    echo "[sync-consumer] created vscode-project-words.txt" \
      "from code_checking baseline"
  else
    echo "[sync-consumer] baseline not found: ${CSPELL_WORDS_BASELINE}" >&2
  fi
fi

echo "[sync-consumer] complete"
