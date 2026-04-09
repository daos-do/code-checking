#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TARGET_ROOT="$(pwd)"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target-root)
      TARGET_ROOT="$2"
      shift 2
      ;;
    --help|-h)
      cat <<'EOF'
Usage: setup-dev.sh [--target-root PATH]

Checks local prerequisites and installs or refreshes pre-commit hooks in the
target repository.

Defaults:
- target root: current directory
EOF
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

TARGET_ROOT="$(cd "${TARGET_ROOT}" && pwd)"

infer_code_checking_path() {
  if [[ "${LIB_ROOT}" == "${TARGET_ROOT}" ]]; then
    printf '.\n'
    return 0
  fi

  if [[ "${LIB_ROOT}/" == "${TARGET_ROOT}/"* ]]; then
    local inferred_path="${LIB_ROOT#"${TARGET_ROOT}/"}"
    if [[ -n "${inferred_path}" && "${inferred_path}" != "${LIB_ROOT}" ]]; then
      printf '%s\n' "${inferred_path}"
      return 0
    fi
  fi

  if [[ -d "${TARGET_ROOT}/code_checking" ]]; then
    printf 'code_checking\n'
    return 0
  fi

  return 1
}

create_pre_commit_config_if_missing() {
  local config_path="${TARGET_ROOT}/.pre-commit-config.yaml"
  if [[ -f "${config_path}" ]]; then
    return 0
  fi

  local code_checking_path=""
  if ! code_checking_path="$(infer_code_checking_path)"; then
    echo "[setup-dev] no .pre-commit-config.yaml found and unable to locate code_checking path from ${TARGET_ROOT}" >&2
    echo "[setup-dev] expected submodule at ${TARGET_ROOT}/code_checking or setup-dev script under the target root" >&2
    return 1
  fi

  local hook_prefix="."
  if [[ "${code_checking_path}" != "." ]]; then
    hook_prefix="./${code_checking_path}"
  fi

  cat > "${config_path}" <<EOF
repos:
  - repo: local
    hooks:
      - id: forbid-code-checking-ref
        name: forbid tracked .code-checking-ref
        entry: ${hook_prefix}/checks/guard-code-checking-ref.sh --target-root .
        language: script
        pass_filenames: false
        always_run: true
        stages: [commit]
        require_serial: true
      - id: verify-executable-modes
        name: verify executable modes
        entry: ${hook_prefix}/checks/verify-executable-modes.sh --target-root .
        language: script
        pass_filenames: false
        always_run: true
        stages: [commit]
        require_serial: true
      - id: shellcheck
        name: shellcheck
        entry: ${hook_prefix}/bin/run-linters.sh --mode changed --target-root .
        language: script
        pass_filenames: false
        types: [shell]
        stages: [commit]
        require_serial: false
EOF

  echo "[setup-dev] created .pre-commit-config.yaml using ${hook_prefix} hooks"
}

check_and_install_tool() {
  local tool_name="$1"

  if command -v "$tool_name" >/dev/null 2>&1; then
    echo "[setup-dev] ✓ $tool_name found"
    return 0
  fi

  echo "[setup-dev] ✗ $tool_name not found, attempting to install..."

  case "$(uname -s)" in
    Darwin)
      # macOS with Homebrew
      if command -v brew >/dev/null 2>&1; then
        echo "[setup-dev] installing $tool_name via homebrew..."
        brew install "$tool_name"
        return $?
      else
        echo "[setup-dev] homebrew not found; install it first or install $tool_name manually" >&2
        return 1
      fi
      ;;
    Linux)
      # Try apt first (Debian/Ubuntu)
      if command -v apt-get >/dev/null 2>&1; then
        echo "[setup-dev] installing $tool_name via apt-get..."
        sudo apt-get update
        sudo apt-get install -y "$tool_name"
        return $?
      # Try dnf (Fedora/RHEL)
      elif command -v dnf >/dev/null 2>&1; then
        echo "[setup-dev] installing $tool_name via dnf..."
        sudo dnf install -y "$tool_name"
        return $?
      # Try yum (older RHEL)
      elif command -v yum >/dev/null 2>&1; then
        echo "[setup-dev] installing $tool_name via yum..."
        sudo yum install -y "$tool_name"
        return $?
      else
        echo "[setup-dev] no package manager found; install $tool_name manually" >&2
        return 1
      fi
      ;;
    *)
      echo "[setup-dev] unknown OS; install $tool_name manually" >&2
      return 1
      ;;
  esac
}

install_python_package() {
  local pkg_name="$1"

  # On Linux, try distro package manager only (no pip fallback)
  case "$(uname -s)" in
    Linux)
      if command -v apt-get >/dev/null 2>&1; then
        echo "[setup-dev] installing $pkg_name via apt-get..."
        sudo apt-get update
        sudo apt-get install -y "$pkg_name"
        return $?
      elif command -v dnf >/dev/null 2>&1; then
        echo "[setup-dev] installing $pkg_name via dnf..."
        sudo dnf install -y "$pkg_name"
        return $?
      elif command -v yum >/dev/null 2>&1; then
        echo "[setup-dev] installing $pkg_name via yum..."
        sudo yum install -y "$pkg_name"
        return $?
      else
        echo "[setup-dev] $pkg_name not found in distro repositories" >&2
        echo "[setup-dev] install via your Linux distro package manager (apt, dnf, yum, etc.)" >&2
        return 1
      fi
      ;;
    # On non-Linux systems, allow user-scoped pip fallback (macOS, etc.)
    *)
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
        echo "[setup-dev] neither distro package manager nor pip found; install $pkg_name manually" >&2
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

# Check and install shellcheck
if ! check_and_install_tool shellcheck; then
  echo "[setup-dev] note: shellcheck is required for pre-commit shell linting" >&2
  echo "[setup-dev] continuing despite missing shellcheck (check will fail until installed)" >&2
fi

if ! create_pre_commit_config_if_missing; then
  exit 1
fi

# Initialize pre-commit hooks only when target repo is configured for pre-commit
if [[ ! -d "${TARGET_ROOT}/.git" ]]; then
  echo "[setup-dev] not a git repository; skipping pre-commit hook initialization"
elif [[ ! -f "${TARGET_ROOT}/.pre-commit-config.yaml" ]]; then
  echo "[setup-dev] no .pre-commit-config.yaml in target root; skipping hook initialization"
else
  echo "[setup-dev] initializing pre-commit hooks..."
  cd "${TARGET_ROOT}"
  pre-commit install --install-hooks
  echo "[setup-dev] pre-commit hooks initialized"
fi

echo "[setup-dev] setup complete"
