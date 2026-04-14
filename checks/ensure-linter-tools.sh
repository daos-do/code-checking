#!/usr/bin/env bash
# Copyright 2026 Hewlett Packard Enterprise Development LP
set -euo pipefail

if [[ $# -eq 0 ]]; then
  echo "Usage: ensure-linter-tools.sh <linter> [<linter> ...]" >&2
  exit 2
fi

missing_tools=0

print_install_hint() {
  local tool_name="$1"
  case "$(uname -s)" in
    Darwin)
      echo "[linters] install hint (macOS): brew install ${tool_name}" >&2
      ;;
    Linux)
      echo "[linters] install hint (Debian/Ubuntu): sudo apt-get update; sudo apt-get install -y ${tool_name}" >&2
      echo "[linters] install hint (Fedora): sudo dnf install -y ${tool_name}" >&2
      ;;
    *)
      echo "[linters] install hint: install '${tool_name}' and ensure it is on PATH" >&2
      ;;
  esac
}

for linter in "$@"; do
  case "${linter}" in
    shellcheck)
      if ! command -v shellcheck >/dev/null 2>&1; then
        echo "[linters] missing required tool for '${linter}': shellcheck" >&2
        print_install_hint shellcheck
        missing_tools=1
      fi
      ;;
    codespell)
      if ! command -v codespell >/dev/null 2>&1; then
        echo "[linters] missing required tool for '${linter}': codespell" >&2
        print_install_hint codespell
        missing_tools=1
      fi
      ;;
    *)
      # Unknown linters are handled by the main runner.
      ;;
  esac
done

if [[ "${missing_tools}" -ne 0 ]]; then
  echo "[linters] one or more required tools are missing" >&2
  exit 127
fi

echo "[linters] tool preflight checks passed"
