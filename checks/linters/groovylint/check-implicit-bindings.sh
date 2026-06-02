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
  # Exclude assignments inside declarative `environment { }` blocks (legitimate).
  violations_in_file=$(awk '
    BEGIN { in_environment = 0; env_brace_depth = 0 }
    /environment[[:space:]]*\{/ {
      in_environment = 1
      env_brace_depth += gsub(/\{/, "{")
      env_brace_depth -= gsub(/\}/, "}")
      next
    }
    in_environment {
      env_brace_depth += gsub(/\{/, "{")
      env_brace_depth -= gsub(/\}/, "}")
      if (env_brace_depth <= 0) {
        in_environment = 0
      }
      next
    }
    !in_environment && /^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]*=[^=~]/ {
      print NR": "$0
      exit 1
    }
    END { exit 0 }
  ' "${file_path}" 2>/dev/null) || {
    if [[ -n "${violations_in_file}" ]]; then
      echo "[groovylint] implicit script-binding assignment detected: ${file_path}" >&2
      awk '
        BEGIN { in_environment = 0; env_brace_depth = 0 }
        /environment[[:space:]]*\{/ {
          in_environment = 1
          env_brace_depth += gsub(/\{/, "{")
          env_brace_depth -= gsub(/\}/, "}")
          next
        }
        in_environment {
          env_brace_depth += gsub(/\{/, "{")
          env_brace_depth -= gsub(/\}/, "}")
          if (env_brace_depth <= 0) {
            in_environment = 0
          }
          next
        }
        !in_environment && /^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]*=[^=~]/ {
          print NR": "$0
        }
      ' "${file_path}" >&2
      violations=1
    fi
  }
done

if [[ ${violations} -ne 0 ]]; then
  echo "[groovylint] use explicit declarations (for example: def/typed variable)" >&2
  echo "[groovylint] implicit binding assignments are blocked for Jenkins safety" >&2
  exit 1
fi
