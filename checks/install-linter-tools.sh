#!/usr/bin/env bash
# Copyright 2026 Hewlett Packard Enterprise Development LP
set -euo pipefail

LIB_ROOT=""
TARGET_ROOT=""
MODE="changed"
BASE_REF="${GITHUB_BASE_REF:-}"
NPM_GROOVY_LINT_VERSION="13.0.2"
MARKDOWNLINT_CLI_VERSION="0.39.0"
# Ubuntu/WSL: distro Node packages may install but have a broken ELF interpreter
# path. The helpers below detect this and work around it at runtime.
NODE_ELF_LOADER="/lib64/ld-linux-x86-64.so.2"

usage() {
  cat <<'EOF'
Usage: install-linter-tools.sh --library-root PATH --target-root PATH \
                               [--mode changed|full] [--base-ref REF]

Installs required external linter tools for the selected file set.
Supports macOS (Homebrew), Debian/Ubuntu (apt-get), and RHEL-compatible
platforms (dnf/yum).
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
    --mode)
      MODE="$2"
      shift 2
      ;;
    --base-ref)
      BASE_REF="$2"
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
  echo "--library-root and --target-root are required" >&2
  exit 2
fi

LIB_ROOT="$(cd "${LIB_ROOT}" && pwd)"
TARGET_ROOT="$(cd "${TARGET_ROOT}" && pwd)"

detect_args=(
  --library-root "${LIB_ROOT}"
  --target-root "${TARGET_ROOT}"
  --mode "${MODE}"
)
if [[ -n "${BASE_REF}" ]]; then
  detect_args+=(--base-ref "${BASE_REF}")
fi

mapfile -t REQUIRED_LINTERS < <(
  bash "${LIB_ROOT}/checks/detect-linters.sh" "${detect_args[@]}"
)

if [[ ${#REQUIRED_LINTERS[@]} -eq 0 ]]; then
  echo "[linters] no applicable linters for selected files"
  echo "[linters] no external linter tools to install"
  exit 0
fi

# ---------------------------------------------------------------------------
# Node/npm helper functions
# On Ubuntu/WSL, distro Node packages may install but have a broken ELF
# interpreter path. The helpers below detect and work around this condition.
# ---------------------------------------------------------------------------

sudo_cmd() {
  if [[ "$(id -u)" -eq 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

have_working_node_via_loader() {
  [[ -x "${NODE_ELF_LOADER}" ]] && [[ -x /usr/bin/node ]] &&
    "${NODE_ELF_LOADER}" /usr/bin/node --version > /dev/null 2>&1
}

get_npm_cli_path() {
  local npm_cli=''
  for npm_cli in \
    /usr/share/nodejs/npm/bin/npm-cli.js \
    /usr/lib/node_modules/npm/bin/npm-cli.js; do
    if [[ -f "${npm_cli}" ]]; then
      echo "${npm_cli}"
      return 0
    fi
  done
  return 1
}

# Run npm; fall back to ELF-loader invocation when the npm wrapper is broken.
npm_cmd() {
  if command -v npm >/dev/null 2>&1 && npm --version > /dev/null 2>&1; then
    npm "$@"
    return $?
  fi
  local npm_cli=''
  if have_working_node_via_loader && npm_cli="$(get_npm_cli_path 2>/dev/null)"; then
    "${NODE_ELF_LOADER}" /usr/bin/node "${npm_cli}" "$@"
    return $?
  fi
  return 1
}

# Same as npm_cmd but wrapped in sudo (or direct when already root).
npm_cmd_sudo() {
  if sudo_cmd npm --version > /dev/null 2>&1; then
    sudo_cmd npm "$@"
    return $?
  fi
  local npm_cli=''
  if [[ -x "${NODE_ELF_LOADER}" ]] && [[ -x /usr/bin/node ]] &&
    npm_cli="$(get_npm_cli_path 2>/dev/null)"; then
    sudo_cmd "${NODE_ELF_LOADER}" /usr/bin/node "${npm_cli}" "$@"
    return $?
  fi
  return 1
}

have_working_npm() {
  npm_cmd --version > /dev/null 2>&1
}

get_groovylint_cli_script_path() {
  local global_root=''
  global_root="$(npm_cmd root -g 2>/dev/null | tr -d '\r' | head -n1 || true)"
  local candidate=''
  for candidate in \
    "${global_root}/npm-groovy-lint/bin/npm-groovy-lint.js" \
    "${global_root}/npm-groovy-lint/lib/index.js" \
    /usr/local/lib/node_modules/npm-groovy-lint/bin/npm-groovy-lint.js \
    /usr/local/lib/node_modules/npm-groovy-lint/lib/index.js \
    /usr/lib/node_modules/npm-groovy-lint/bin/npm-groovy-lint.js \
    /usr/lib/node_modules/npm-groovy-lint/lib/index.js; do
    if [[ -n "${candidate}" ]] && [[ -f "${candidate}" ]]; then
      echo "${candidate}"
      return 0
    fi
  done
  return 1
}

# Verify npm-groovy-lint works; if not, attempt an ELF-loader wrapper install.
ensure_groovylint_command_works() {
  if command -v npm-groovy-lint >/dev/null 2>&1 &&
    npm-groovy-lint --version > /dev/null 2>&1; then
    return 0
  fi
  have_working_node_via_loader || return 1
  local script=''
  script="$(get_groovylint_cli_script_path 2>/dev/null || true)"
  [[ -z "${script}" ]] && return 1
  echo "[linters] node runtime requires ELF loader; creating npm-groovy-lint wrapper"
  local tmp=''
  tmp="$(mktemp)"
  printf '#!/bin/bash\nexec "%s" /usr/bin/node "%s" "$@"\n' \
    "${NODE_ELF_LOADER}" "${script}" > "${tmp}"
  chmod 0755 "${tmp}"
  local target=''
  if sudo_cmd install -m 0755 "${tmp}" /usr/local/bin/npm-groovy-lint 2>/dev/null; then
    target="/usr/local/bin/npm-groovy-lint"
  else
    mkdir -p "${HOME}/.local/bin"
    install -m 0755 "${tmp}" "${HOME}/.local/bin/npm-groovy-lint"
    target="${HOME}/.local/bin/npm-groovy-lint"
    export PATH="${HOME}/.local/bin:${PATH}"
  fi
  rm -f "${tmp}"
  echo "[linters] installed npm-groovy-lint wrapper at ${target}"
  npm-groovy-lint --version > /dev/null 2>&1
}

get_markdownlint_cli_script_path() {
  local global_root=''
  global_root="$(npm_cmd root -g 2>/dev/null | tr -d '\r' | head -n1 || true)"
  local candidate=''
  for candidate in \
    "${global_root}/markdownlint-cli/markdownlint.js" \
    /usr/local/lib/node_modules/markdownlint-cli/markdownlint.js \
    /usr/lib/node_modules/markdownlint-cli/markdownlint.js; do
    if [[ -n "${candidate}" ]] && [[ -f "${candidate}" ]]; then
      echo "${candidate}"
      return 0
    fi
  done
  return 1
}

# Verify markdownlint works; if not, attempt an ELF-loader wrapper install.
ensure_markdownlint_command_works() {
  if command -v markdownlint >/dev/null 2>&1 &&
    markdownlint --version > /dev/null 2>&1; then
    return 0
  fi
  have_working_node_via_loader || return 1
  local script=''
  script="$(get_markdownlint_cli_script_path 2>/dev/null || true)"
  [[ -z "${script}" ]] && return 1
  echo "[linters] node runtime requires ELF loader; creating markdownlint wrapper"
  local tmp=''
  tmp="$(mktemp)"
  printf '#!/bin/bash\nexec "%s" /usr/bin/node "%s" "$@"\n' \
    "${NODE_ELF_LOADER}" "${script}" > "${tmp}"
  chmod 0755 "${tmp}"
  local target=''
  if sudo_cmd install -m 0755 "${tmp}" /usr/local/bin/markdownlint 2>/dev/null; then
    target="/usr/local/bin/markdownlint"
  else
    mkdir -p "${HOME}/.local/bin"
    install -m 0755 "${tmp}" "${HOME}/.local/bin/markdownlint"
    target="${HOME}/.local/bin/markdownlint"
    export PATH="${HOME}/.local/bin:${PATH}"
  fi
  rm -f "${tmp}"
  echo "[linters] installed markdownlint wrapper at ${target}"
  markdownlint --version > /dev/null 2>&1
}

# ---------------------------------------------------------------------------
# Platform package installation
# ---------------------------------------------------------------------------

PACKAGES=()
for linter in "${REQUIRED_LINTERS[@]}"; do
  case "${linter}" in
    shellcheck)   PACKAGES+=("shellcheck") ;;
    groovylint)   PACKAGES+=("npm") ;;
    markdownlint) PACKAGES+=("npm") ;;
    codespell)    PACKAGES+=("codespell")  ;;
    *)            continue                 ;;
  esac
done

# Deduplicate (npm may appear for both groovylint and markdownlint).
if [[ ${#PACKAGES[@]} -gt 0 ]]; then
  mapfile -t PACKAGES < <(printf '%s\n' "${PACKAGES[@]}" | sort -u)
fi

if [[ ${#PACKAGES[@]} -eq 0 ]]; then
  echo "[linters] selected linters do not require external tool install"
  exit 0
fi

MISSING_PACKAGES=()
for package in "${PACKAGES[@]}"; do
  case "${package}" in
    npm)
      if have_working_npm; then
        echo "[linters] already installed: npm"
        continue
      fi
      ;;
    *)
      if command -v "${package}" >/dev/null 2>&1; then
        echo "[linters] already installed: ${package}"
        continue
      fi
      ;;
  esac
  MISSING_PACKAGES+=("${package}")
done

if [[ ${#MISSING_PACKAGES[@]} -eq 0 ]]; then
  echo "[linters] required platform tools already present"
else
  echo "[linters] installing packages: ${MISSING_PACKAGES[*]}"

  case "$(uname -s)" in
    Darwin)
      if ! command -v brew >/dev/null 2>&1; then
        echo "[linters] homebrew not found; install it or install tools manually" >&2
        echo "[linters] required packages: ${MISSING_PACKAGES[*]}" >&2
        exit 127
      fi
      DARWIN_PACKAGES=()
      for package in "${MISSING_PACKAGES[@]}"; do
        if [[ "${package}" == "npm" ]]; then
          # Homebrew installs npm via the node package.
          DARWIN_PACKAGES+=("node")
        else
          DARWIN_PACKAGES+=("${package}")
        fi
      done
      brew install "${DARWIN_PACKAGES[@]}"
      ;;
    Linux)
      SUDO_CMD=()
      if [[ "$(id -u)" -ne 0 ]]; then
        if command -v sudo >/dev/null 2>&1; then
          SUDO_CMD=(sudo)
        else
          echo "[linters] sudo not found and not running as root" >&2
          echo "[linters] required packages: ${MISSING_PACKAGES[*]}" >&2
          exit 127
        fi
      fi

      LINUX_PACKAGES=()
      for package in "${MISSING_PACKAGES[@]}"; do
        if [[ "${package}" == "npm" ]]; then
          # Ubuntu/WSL reliability: install both nodejs and npm together.
          LINUX_PACKAGES+=("nodejs" "npm")
        else
          LINUX_PACKAGES+=("${package}")
        fi
      done

      if command -v apt-get >/dev/null 2>&1; then
        "${SUDO_CMD[@]}" apt-get update
        # Use --reinstall so a broken distro Node install (e.g. Ubuntu/WSL ELF
        # interpreter mismatch) is corrected when nodejs/npm are in the list.
        "${SUDO_CMD[@]}" apt-get install --reinstall -y "${LINUX_PACKAGES[@]}"
      elif command -v dnf >/dev/null 2>&1; then
        "${SUDO_CMD[@]}" dnf install -y "${LINUX_PACKAGES[@]}"
      elif command -v yum >/dev/null 2>&1; then
        "${SUDO_CMD[@]}" yum install -y "${LINUX_PACKAGES[@]}"
      else
        echo "[linters] no supported package manager found (apt-get/dnf/yum)" >&2
        echo "[linters] required packages: ${MISSING_PACKAGES[*]}" >&2
        exit 127
      fi
      ;;
    *)
      echo "[linters] unsupported platform '$(uname -s)'; install tools manually" >&2
      echo "[linters] required packages: ${MISSING_PACKAGES[*]}" >&2
      exit 127
      ;;
  esac
fi

# ---------------------------------------------------------------------------
# npm-based tool installation
# ---------------------------------------------------------------------------

if printf '%s\n' "${REQUIRED_LINTERS[@]}" | grep -Fxq 'groovylint'; then
  INSTALLED_GROOVY_LINT_VERSION=""
  if command -v npm-groovy-lint >/dev/null 2>&1 && ensure_groovylint_command_works; then
    INSTALLED_GROOVY_LINT_VERSION="$({ npm-groovy-lint --version || true; } \
      | awk '/npm-groovy-lint version/{print $NF; exit}')"
  fi

  if [[ "${INSTALLED_GROOVY_LINT_VERSION}" == "${NPM_GROOVY_LINT_VERSION}" ]]; then
    echo "[linters] already installed: npm-groovy-lint@${NPM_GROOVY_LINT_VERSION}"
  else
    if [[ -n "${INSTALLED_GROOVY_LINT_VERSION}" ]]; then
      echo "[linters] updating npm-groovy-lint from ${INSTALLED_GROOVY_LINT_VERSION} to ${NPM_GROOVY_LINT_VERSION}"
    else
      echo "[linters] installing npm-groovy-lint@${NPM_GROOVY_LINT_VERSION} via npm"
    fi
    if ! have_working_npm; then
      echo "[linters] npm runtime is not working; cannot install npm-groovy-lint" >&2
      exit 127
    fi
    if ! npm_cmd install --global "npm-groovy-lint@${NPM_GROOVY_LINT_VERSION}" > /dev/null 2>&1; then
      echo "[linters] retrying npm-groovy-lint install with sudo"
      npm_cmd_sudo install --global "npm-groovy-lint@${NPM_GROOVY_LINT_VERSION}"
    fi
    if ! ensure_groovylint_command_works; then
      echo "[linters] npm-groovy-lint installed but command is not working" >&2
      exit 1
    fi
  fi
fi

if printf '%s\n' "${REQUIRED_LINTERS[@]}" | grep -Fxq 'markdownlint'; then
  INSTALLED_MARKDOWNLINT_VERSION=""
  if command -v markdownlint >/dev/null 2>&1 && ensure_markdownlint_command_works; then
    INSTALLED_MARKDOWNLINT_VERSION="$(markdownlint --version 2>/dev/null \
      | head -n1 | tr -d '\r' || true)"
  fi

  if [[ "${INSTALLED_MARKDOWNLINT_VERSION}" == "${MARKDOWNLINT_CLI_VERSION}" ]]; then
    echo "[linters] already installed: markdownlint@${MARKDOWNLINT_CLI_VERSION}"
  else
    if [[ -n "${INSTALLED_MARKDOWNLINT_VERSION}" ]]; then
      echo "[linters] updating markdownlint from ${INSTALLED_MARKDOWNLINT_VERSION} to ${MARKDOWNLINT_CLI_VERSION}"
    else
      echo "[linters] installing markdownlint-cli@${MARKDOWNLINT_CLI_VERSION} via npm"
    fi
    if ! have_working_npm; then
      echo "[linters] npm runtime is not working; cannot install markdownlint" >&2
      exit 127
    fi
    if ! npm_cmd install --global --ignore-scripts \
      "markdownlint-cli@${MARKDOWNLINT_CLI_VERSION}" > /dev/null 2>&1; then
      echo "[linters] retrying markdownlint install with sudo"
      npm_cmd_sudo install --global --ignore-scripts \
        "markdownlint-cli@${MARKDOWNLINT_CLI_VERSION}"
    fi
    if ! ensure_markdownlint_command_works; then
      echo "[linters] markdownlint installed but command is not working" >&2
      exit 1
    fi
  fi
fi
