#!/usr/bin/env bash
# Copyright 2026 Hewlett Packard Enterprise Development LP
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

PYTHON_CMD=""
PYTHON_ARGS=()

# On Windows shells such as Git Bash/MSYS, prefer native Windows Python over
# the POSIX-layer /usr/bin/python3 so subprocess calls to VS Code CLI wrappers
# behave consistently.
if [[ "${OS:-}" == "Windows_NT" || "${MSYSTEM:-}" != "" || "${OSTYPE:-}" == msys* || "${OSTYPE:-}" == cygwin* ]]; then
  if command -v python.exe >/dev/null 2>&1; then
    PYTHON_CMD="$(command -v python.exe)"
  elif command -v py.exe >/dev/null 2>&1; then
    PYTHON_CMD="$(command -v py.exe)"
    PYTHON_ARGS=(-3)
  fi
fi

if [[ -z "${PYTHON_CMD}" ]]; then
  if command -v python3 >/dev/null 2>&1; then
    PYTHON_CMD="$(command -v python3)"
  elif command -v python >/dev/null 2>&1; then
    PYTHON_CMD="$(command -v python)"
  fi
fi

if [[ -z "${PYTHON_CMD}" ]]; then
  echo "python3 is required for bin/ide-workspace-setup.sh" >&2
  echo "run ./bin/bootstrap-python.sh first" >&2
  exit 1
fi

exec "${PYTHON_CMD}" "${PYTHON_ARGS[@]}" \
     "${REPO_ROOT}/bin/ide-workspace-setup.py" "$@"
