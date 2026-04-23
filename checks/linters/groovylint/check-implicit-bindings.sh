#!/usr/bin/env bash
# Copyright 2026 Hewlett Packard Enterprise Development LP
set -euo pipefail

if [[ $# -eq 0 ]]; then
  exit 0
fi

violations=0
for file_path in "$@"; do
  [[ -f "${file_path}" ]] || continue

  case "${file_path##*/}" in
    *.groovy|Jenkinsfile*)
      ;;
    *)
      continue
      ;;
  esac

  # Guard against Groovy script binding side effects from bare assignments like
  # `myVar = value`. In Jenkins pipelines these become shared script properties
  # and can cause nondeterministic behavior in parallel execution.
  if grep -nE '^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]*=[^=~]' \
    "${file_path}" >/dev/null; then
    echo "[groovylint] implicit script-binding assignment detected: ${file_path}" >&2
    grep -nE '^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]*=[^=~]' \
      "${file_path}" >&2
    violations=1
  fi
done

if [[ ${violations} -ne 0 ]]; then
  echo "[groovylint] use explicit declarations (for example: def/typed variable)" >&2
  echo "[groovylint] implicit binding assignments are blocked for Jenkins safety" >&2
  exit 1
fi
