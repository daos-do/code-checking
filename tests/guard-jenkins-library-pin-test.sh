#!/usr/bin/env bash
# Copyright 2026 Hewlett Packard Enterprise Development LP
set -euo pipefail

# Unit tests for checks/guard-jenkins-library-pin.sh
#
# SRE-3850: validates the awk regex portability fix for @Library pattern
# matching.  Each case builds a minimal temporary git repository with a
# fixture Jenkinsfile, runs the guard, and verifies:
#   - expected exit code
#   - expected stdout/stderr content
#   - absence of the SRE-3850 awk regression (warning/fatal on stderr)
#
# Usage: bash tests/guard-jenkins-library-pin-test.sh

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GUARD="${REPO_ROOT}/checks/guard-jenkins-library-pin.sh"

pass_count=0
fail_count=0

WORK_DIR=""
cleanup_all() {
  if [[ -n "${WORK_DIR}" ]]; then
    # git writes object files read-only; restore write permission before removal.
    chmod -R u+w "${WORK_DIR}" 2>/dev/null || true
    rm -rf "${WORK_DIR}" 2>/dev/null || true
  fi
}
trap cleanup_all EXIT

WORK_DIR="$(mktemp -d)"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

pass() { echo "[PASS] $1"; pass_count=$(( pass_count + 1 )); }
fail() { echo "[FAIL] $1" >&2; fail_count=$(( fail_count + 1 )); }

# make_repo DIR
# Initialize a throwaway git repo with a committed state ready for ls-files.
make_repo() {
  local dir="$1"
  mkdir -p "${dir}"
  git -C "${dir}" init -q
  git -C "${dir}" config user.email "test@test.local"
  git -C "${dir}" config user.name "Test"
}

# commit_file REPO_DIR REL_PATH
# Stage and commit the file at REL_PATH inside REPO_DIR.
commit_file() {
  local dir="$1"
  local rel="$2"
  git -C "${dir}" add "${rel}"
  git -C "${dir}" commit -qm "test fixture: ${rel}"
}

# run_case NAME WORKDIR EXPECTED_EXIT [STDOUT_SUBSTR] [STDERR_SUBSTR]
# Runs the guard and reports pass/fail.  Always checks for the SRE-3850
# awk portability regression regardless of other assertions.
run_case() {
  local name="$1"
  local workdir="$2"
  local expected_exit="$3"
  local stdout_substr="${4:-}"
  local stderr_substr="${5:-}"

  local out_file="${WORK_DIR}/${name}.out"
  local err_file="${WORK_DIR}/${name}.err"
  local actual_exit=0

  "${GUARD}" --target-root "${workdir}" \
    >"${out_file}" 2>"${err_file}" || actual_exit=$?

  local ok=1

  # --- exit code check ---
  if [[ "${actual_exit}" -ne "${expected_exit}" ]]; then
    echo "  [${name}] expected exit ${expected_exit}, got ${actual_exit}" >&2
    echo "  stdout: $(cat "${out_file}")" >&2
    echo "  stderr: $(cat "${err_file}")" >&2
    ok=0
  fi

  # --- stdout content check ---
  if [[ -n "${stdout_substr}" ]] && \
       ! grep -qF "${stdout_substr}" "${out_file}"; then
    echo "  [${name}] stdout missing: ${stdout_substr}" >&2
    echo "  stdout was: $(cat "${out_file}")" >&2
    ok=0
  fi

  # --- stderr content check ---
  if [[ -n "${stderr_substr}" ]] && \
       ! grep -qF "${stderr_substr}" "${err_file}"; then
    echo "  [${name}] stderr missing: ${stderr_substr}" >&2
    echo "  stderr was: $(cat "${err_file}")" >&2
    ok=0
  fi

  if [[ "${ok}" -eq 1 ]]; then
    pass "${name}"
  else
    fail "${name}"
  fi
}

# ---------------------------------------------------------------------------
# Case 1 — no Jenkinsfile in repo: guard exits 0, reports no candidates
# ---------------------------------------------------------------------------
{
  d="${WORK_DIR}/case_no_jenkinsfile"
  make_repo "${d}"
  touch "${d}/README.md"
  commit_file "${d}" README.md

  run_case \
    "no_jenkinsfile" "${d}" 0 \
    "no Jenkinsfile candidates found"
}

# ---------------------------------------------------------------------------
# Case 2 — Jenkinsfile with no @Library: guard exits 0, reports ok
# ---------------------------------------------------------------------------
{
  d="${WORK_DIR}/case_clean"
  make_repo "${d}"
  cat > "${d}/Jenkinsfile" <<'GROOVY'
pipeline {
  agent any
  stages {
    stage('build') { steps { sh 'make' } }
  }
}
GROOVY
  commit_file "${d}" Jenkinsfile

  run_case \
    "clean_jenkinsfile" "${d}" 0 \
    "no active @Library references found"
}

# ---------------------------------------------------------------------------
# Case 3 — active @Library reference: guard exits 1, reports blocked
# This is the primary SRE-3850 regression case; the awk regex must not
# crash before it has a chance to detect the pattern.
# ---------------------------------------------------------------------------
{
  d="${WORK_DIR}/case_active_library"
  make_repo "${d}"
  cat > "${d}/Jenkinsfile" <<'GROOVY'
@Library("my-shared-lib") _
pipeline {
  agent any
  stages {
    stage('build') { steps { sh 'make' } }
  }
}
GROOVY
  commit_file "${d}" Jenkinsfile

  run_case \
    "active_library_blocked" "${d}" 1 \
    "" \
    "blocked: active @Library reference"
}

# ---------------------------------------------------------------------------
# Case 4 — @Library in a // line comment: must be ignored, guard exits 0
# ---------------------------------------------------------------------------
{
  d="${WORK_DIR}/case_line_comment"
  make_repo "${d}"
  cat > "${d}/Jenkinsfile" <<'GROOVY'
// @Library("my-shared-lib") _
pipeline {
  agent any
  stages {
    stage('build') { steps { sh 'make' } }
  }
}
GROOVY
  commit_file "${d}" Jenkinsfile

  run_case \
    "library_in_line_comment_ignored" "${d}" 0 \
    "no active @Library references found"
}

# ---------------------------------------------------------------------------
# Case 5 — @Library inside a /* */ block comment: must be ignored, exits 0
# ---------------------------------------------------------------------------
{
  d="${WORK_DIR}/case_block_comment"
  make_repo "${d}"
  cat > "${d}/Jenkinsfile" <<'GROOVY'
/*
 * Example usage: @Library("my-shared-lib") _
 */
pipeline {
  agent any
  stages {
    stage('build') { steps { sh 'make' } }
  }
}
GROOVY
  commit_file "${d}" Jenkinsfile

  run_case \
    "library_in_block_comment_ignored" "${d}" 0 \
    "no active @Library references found"
}

# ---------------------------------------------------------------------------
# Case 6 — @Library with whitespace before paren (spacing variant): blocked
# Validates that [[:space:]]* in the pattern still matches after the portability fix.
# ---------------------------------------------------------------------------
{
  d="${WORK_DIR}/case_spaced_paren"
  make_repo "${d}"
  cat > "${d}/Jenkinsfile" <<'GROOVY'
@Library  ("my-shared-lib") _
pipeline {
  agent any
}
GROOVY
  commit_file "${d}" Jenkinsfile

  run_case \
    "library_spaced_paren_blocked" "${d}" 1 \
    "" \
    "blocked: active @Library reference"
}

# ---------------------------------------------------------------------------
# Case 7 — Jenkinsfile in a subdirectory: guard must detect it
# ---------------------------------------------------------------------------
{
  d="${WORK_DIR}/case_subdir"
  make_repo "${d}"
  mkdir -p "${d}/jobs"
  cat > "${d}/jobs/Jenkinsfile" <<'GROOVY'
@Library("my-shared-lib") _
pipeline { agent any }
GROOVY
  commit_file "${d}" jobs/Jenkinsfile

  run_case \
    "active_library_in_subdir_blocked" "${d}" 1 \
    "" \
    "blocked: active @Library reference"
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "Results: ${pass_count} passed, ${fail_count} failed"

if [[ "${fail_count}" -ne 0 ]]; then
  exit 1
fi
