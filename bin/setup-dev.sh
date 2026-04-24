#!/usr/bin/env bash
# Copyright 2026 Hewlett Packard Enterprise Development LP
set -euo pipefail

TARGET_ROOT="$(pwd)"
CODE_CHECKING_PATH=""
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

usage() {
  echo "Usage: setup-dev.sh [--target-root PATH] [--code-checking-path PATH]"
  echo
  echo "Checks local prerequisites and installs or refreshes pre-commit hooks in the"
  echo "target repository."
  echo
  echo "Defaults:"
  echo "- target root: current directory"
  echo
  echo "Required for bootstrap:"
  echo "- --code-checking-path must be provided when .pre-commit-config.yaml is missing"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target-root)
      if [[ $# -lt 2 || -z "${2}" || "${2}" == --* ]]; then
        echo "Missing value for $1" >&2
        usage >&2
        exit 2
      fi
      TARGET_ROOT="$2"
      shift 2
      ;;
    --code-checking-path)
      if [[ $# -lt 2 || -z "${2}" || "${2}" == --* ]]; then
        echo "Missing value for $1" >&2
        usage >&2
        exit 2
      fi
      CODE_CHECKING_PATH="$2"
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

TARGET_ROOT="$(cd "${TARGET_ROOT}" && pwd)"

create_pre_commit_config_if_missing() {
  local config_path="${TARGET_ROOT}/.pre-commit-config.yaml"
  if [[ -f "${config_path}" ]]; then
    return 0
  fi

  echo "[setup-dev] no .pre-commit-config.yaml found. Creating..."

  if [[ -z "${CODE_CHECKING_PATH}" ]]; then
    # Auto-detect when invoked via a vendored code_checking submodule.
    if [[ "${LIB_ROOT}/" == "${TARGET_ROOT}/"* ]]; then
      CODE_CHECKING_PATH="${LIB_ROOT#"${TARGET_ROOT}/"}"
    fi
  fi

  if [[ -z "${CODE_CHECKING_PATH}" ]]; then
    echo "[setup-dev] unable to locate code_checking path from ${TARGET_ROOT}" >&2
    echo "[setup-dev] provide --code-checking-path (for example: code_checking or .)" >&2
    return 1
  fi

  local code_checking_path="${CODE_CHECKING_PATH#./}"
  if [[ -z "${code_checking_path}" ]]; then
    code_checking_path="."
  fi

  local hook_prefix="."
  if [[ "${code_checking_path}" != "." ]]; then
    hook_prefix="./${code_checking_path}"
  fi

  {
    printf '%s\n' '---'
    printf '%s\n' 'repos:'
    printf '%s\n' '  - repo: local'
    printf '%s\n' '    hooks:'
    printf '%s\n' '      - id: forbid-code-checking-ref'
    printf '%s\n' '        name: forbid tracked code-checking-ref'
    printf '%s\n' "        entry: ${hook_prefix}/checks/guard-code-checking-ref.sh --target-root ."
    printf '%s\n' '        language: script'
    printf '%s\n' '        pass_filenames: false'
    printf '%s\n' '        always_run: true'
    printf '%s\n' '        stages: [commit]'
    printf '%s\n' '        require_serial: true'
    printf '%s\n' '      - id: shellcheck'
    printf '%s\n' '        name: shellcheck'
    printf '%s\n' "        entry: ${hook_prefix}/bin/run-linters.sh --mode changed --target-root ."
    printf '%s\n' '        language: script'
    printf '%s\n' '        pass_filenames: false'
    printf '%s\n' '        types: [shell]'
    printf '%s\n' '        stages: [commit]'
    printf '%s\n' '        require_serial: false'
  } > "${config_path}"

  echo "[setup-dev] created .pre-commit-config.yaml using ${hook_prefix} hooks"
}

install_with_system_package_manager() {
  local package_name="$1"

  if command -v apt-get >/dev/null 2>&1; then
    echo "[setup-dev] installing ${package_name} via apt-get..."
    sudo apt-get update
    sudo apt-get install -y "${package_name}"
    return $?
  fi

  if command -v dnf >/dev/null 2>&1; then
    echo "[setup-dev] installing ${package_name} via dnf..."
    sudo dnf install -y "${package_name}"
    return $?
  fi

  echo "[setup-dev] no supported package manager found." >&2
  return 1
}

install_python_package() {
  local pkg_name="$1"

  # On Linux, try distro package manager only (no pip fallback)
  case "$(uname -s)" in
    Linux)
      install_with_system_package_manager "$pkg_name"
      return $?
      ;;
    # On non-Linux systems, allow user-scoped pip fallback (macOS, etc.)
    *)
      if [[ "$(uname -s)" == "Darwin" ]] && command -v brew >/dev/null 2>&1; then
        echo "[setup-dev] installing $pkg_name via homebrew..."
        brew install "$pkg_name"
        return $?
      fi

      if [[ "$(id -u)" -eq 0 ]]; then
        echo "[setup-dev] refusing to install $pkg_name with pip as root" >&2
        echo "[setup-dev] use system package manager when possible; otherwise rerun as non-root" >&2
        return 1
      fi
      if command -v python3 >/dev/null 2>&1; then
        echo "[setup-dev] installing $pkg_name via python3 -m pip --user..."
        python3 -m pip install --user "$pkg_name"
        return $?
      elif command -v pip3 >/dev/null 2>&1; then
        echo "[setup-dev] installing $pkg_name via pip3 --user..."
        pip3 install --user "$pkg_name"
        return $?
      elif command -v pip >/dev/null 2>&1; then
        echo "[setup-dev] installing $pkg_name via pip --user..."
        pip install --user "$pkg_name"
        return $?
      else
        echo "[setup-dev] no supported automatic installer found; install $pkg_name manually" >&2
        return 1
      fi
      ;;
  esac
}

echo "[setup-dev] checking pre-commit hooks prerequisites"

# Check and install pre-commit
if ! command -v pre-commit >/dev/null 2>&1; then
  echo "[setup-dev] pre-commit not found"
  if ! install_python_package pre-commit; then
    echo "[setup-dev] failed to install pre-commit" >&2
    exit 1
  fi
fi

# Install required external linter tools for this repository content.
if ! "${LIB_ROOT}/checks/install-linter-tools.sh" \
  --library-root "${LIB_ROOT}" \
  --target-root "${TARGET_ROOT}" \
  --mode full; then
  echo "[setup-dev] note: unable to auto-install one or more linter tools" >&2
  echo "[setup-dev] continuing; lint checks may fail until tools are installed" >&2
fi

if ! create_pre_commit_config_if_missing; then
  exit 1
fi

if ! git -C "${TARGET_ROOT}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "[setup-dev] target is not a git repository: ${TARGET_ROOT}" >&2
  exit 1
fi

echo "[setup-dev] initializing pre-commit hooks..."
cd "${TARGET_ROOT}"
pre-commit install --install-hooks
echo "[setup-dev] pre-commit hooks initialized"

echo "[setup-dev] setup complete"
