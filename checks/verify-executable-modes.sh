#!/usr/bin/env bash
# Copyright 2026 Hewlett Packard Enterprise Development LP
set -euo pipefail

TARGET_ROOT="$(pwd)"
FIX_MODE=0
STAGE_MODE=1

usage() {
  cat <<'EOF'
Usage: verify-executable-modes.sh [--target-root PATH] [--fix]

Fails when any tracked file that starts with a shebang (#!) is committed
without executable mode (100755) in the git index. This covers shell scripts,
Python scripts, and any other scripted file regardless of extension.

Use --fix to apply git index mode fixes automatically.
Use --no-stage to apply fixes to files without staging them.
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
    --fix)
      FIX_MODE=1
      shift
      ;;
    --no-stage)
      STAGE_MODE=0
      shift
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
  echo "[verify-exec-mode] target is not a git working tree: ${TARGET_ROOT}" >&2
  exit 2
fi

has_error=0

while IFS= read -r path; do
  [[ -z "${path}" ]] && continue

  file_path="${TARGET_ROOT}/${path}"
  [[ -f "${file_path}" ]] || continue

  first_line="$(head -n 1 "${file_path}" || true)"
  if [[ "${first_line}" != '#!'* ]]; then
    continue
  fi

  mode="$(git -C "${TARGET_ROOT}" ls-files -s -- "${path}" | awk '{print $1}')"
  if [[ -z "${mode}" ]]; then
    continue
  fi

  if [[ "${mode}" != "100755" ]]; then
    if [[ ${FIX_MODE} -eq 1 ]]; then
      if [[ ${STAGE_MODE} -eq 1 ]]; then
        git -C "${TARGET_ROOT}" add --chmod=+x -- "${path}"
        echo "[verify-exec-mode] applied +x in git index: ${path}"
      else
        echo "[verify-exec-mode] needs +x (not staged, --no-stage set):" \
          "${path}"
      fi
    else
      echo "[verify-exec-mode] missing +x in git index:" \
        "${path} (mode ${mode})" >&2
      echo "[verify-exec-mode] fix: git -C \"${TARGET_ROOT}\"" \
        "add --chmod=+x -- \"${path}\"" >&2
      has_error=1
    fi
  fi
done < <(git -C "${TARGET_ROOT}" ls-files)

if [[ "${has_error}" -ne 0 ]]; then
  exit 1
fi

echo "[verify-exec-mode] executable modes are correct"
