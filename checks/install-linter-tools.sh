#!/usr/bin/env bash
# Copyright 2026 Hewlett Packard Enterprise Development LP
set -euo pipefail

LIB_ROOT=""
TARGET_ROOT=""
MODE="changed"
BASE_REF="${GITHUB_BASE_REF:-}"

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

PACKAGES=()
for linter in "${REQUIRED_LINTERS[@]}"; do
  case "${linter}" in
    shellcheck) PACKAGES+=("shellcheck") ;;
    codespell)  PACKAGES+=("codespell")  ;;
    *)          continue                 ;;
  esac
done

if [[ ${#PACKAGES[@]} -eq 0 ]]; then
  echo "[linters] selected linters do not require external tool install"
  exit 0
fi

MISSING_PACKAGES=()
for package in "${PACKAGES[@]}"; do
  if command -v "${package}" >/dev/null 2>&1; then
    echo "[linters] already installed: ${package}"
    continue
  fi
  MISSING_PACKAGES+=("${package}")
done

if [[ ${#MISSING_PACKAGES[@]} -eq 0 ]]; then
  echo "[linters] required tools already present"
  exit 0
fi

echo "[linters] installing packages: ${MISSING_PACKAGES[*]}"

case "$(uname -s)" in
  Darwin)
    if ! command -v brew >/dev/null 2>&1; then
      echo "[linters] homebrew not found; install it or install tools manually" >&2
      echo "[linters] required packages: ${MISSING_PACKAGES[*]}" >&2
      exit 127
    fi
    brew install "${MISSING_PACKAGES[@]}"
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
    if command -v apt-get >/dev/null 2>&1; then
      "${SUDO_CMD[@]}" apt-get update
      "${SUDO_CMD[@]}" apt-get install -y "${MISSING_PACKAGES[@]}"
    elif command -v dnf >/dev/null 2>&1; then
      "${SUDO_CMD[@]}" dnf install -y "${MISSING_PACKAGES[@]}"
    else
      echo "[linters] no supported package manager found (apt-get/dnf)" >&2
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
