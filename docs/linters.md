# Linters

This repository exposes shared linter entrypoints intended to be called either:

- from this repository root while developing the checker library directly, or
- from a consumer repository root through the submodule path.

## Path Model

The linter runner uses two roots:

- Library root: derived from the location of the script in this repository.
- Target root: the repository being checked.

By default, the target root is the current working directory. That means the
same pattern works in both contexts:

```bash
bash ./bin/run-linters.sh
```

```bash
bash ./code_checking/bin/run-linters.sh
```

Both commands lint the repository in the current directory, not the directory
that contains the shared checker scripts.

## Changed-Files Mode

The default mode is `changed`.
In that mode the runner selects linters based on changed paths only.

Selection order:

1. If `--base-ref` is supplied, diff against `origin/<base-ref>...HEAD`.
2. Otherwise, use staged files if any exist.
3. Otherwise, use unstaged changed files.

This keeps PR and pre-commit runs focused on the files being modified.

## Full Mode

Use `--mode full` when you intentionally want a whole-repository lint pass,
such as periodic cleanup or baseline validation.

## First Linter: shellcheck

The first linter wired into the framework is `shellcheck`.
It is selected when changed files include `*.sh` paths outside excluded areas.

Current exclusions:

- `<actual-submodule-path>/*` (the library code itself in consumer repos)

### Pre-commit Integration

Consumer repositories can add this repository's hooks to their `.pre-commit-config.yaml`:

```yaml
repos:
  - repo: https://github.com/daos-do/code-checking
    rev: main
    hooks:
      - id: shellcheck
```

Local pre-commit runs will then use the changed-file mode automatically.
Before running selected linters, the runner verifies that `code_checking` is
at the desired commit resolved from `.code-checking-ref` (or `origin/main`
when that file is missing). The check is non-mutating and fails with sync
commands if the checkout does not match.
The runner also performs a centralized tool preflight check so required linter
executables are present before individual linter scripts run.

Current tool preflight mapping:

- `shellcheck` linter requires `shellcheck` executable on PATH

On Linux/macOS targets, preflight failures include install hints for common
package managers.

### New Linter Tool Installation Convention

When adding new linters (for example markdown or groovy linters), use this
installation policy:

1. Prefer distro package manager installs for Linux hosts.
2. Prefer native platform package managers on macOS (Homebrew).
3. Use language package managers only as a fallback when no platform package
  convention exists.
4. Avoid system-wide `pip` installs on Linux (especially `sudo pip`).
5. Keep tools CLI-accessible on PATH so both pre-commit and CI behavior are
  consistent.

For each new linter integration PR, include:

- tool mapping update in `checks/ensure-linter-tools.sh`
- setup/install guidance update in `bin/setup-dev.sh` and `docs/usage.md`
- preflight failure hints that match the chosen package manager convention

## Suppression Policy

Use global linter configuration files for repository-wide style standards where
the team intentionally differs from tool defaults.

Examples of valid global policy use:

- readability-focused YAML comment alignment rules
- any other site-standard formatting policy that should apply consistently
  across many files

Do not use global suppression as a blanket false-positive workaround.
When a finding is a false positive, or when the recommended rewrite hurts local
readability, suppress it in the file where it occurs.

File-local suppression rules:

- place suppression as close as possible to the affected line/block
- include a short comment explaining why suppression is preferred over code
  rewrite
- keep scope narrow (line/block), not file-wide, unless unavoidable

General rule for all linters:

- prefer code fixes first
- use suppression only when the report is a false positive or when the
  suggested rewrite makes the code harder to read and maintain

ShellCheck-specific guidance:

- ShellCheck is a common case where a suggested rewrite can reduce clarity;
  in that case use a local
  `shellcheck disable=...` with a short rationale comment

## Required Checks in GitHub

Consumer repositories should prefer one stable required workflow job name and
run dynamic linter selection inside that job.
That avoids coupling branch protection to a changing set of per-linter job
names.

Excluded submodule paths are derived from the real location of this repository
relative to the target repository root, so consumer repositories are not tied
to a hardcoded submodule directory name.

## Execution Design Map

This section describes the GitHub Actions and pre-commit check execution design
and what each script or directory is responsible for.

### GitHub Actions Flow

1. Consumer workflow checks out repository content with submodules.
2. Consumer workflow optionally resolves `.code-checking-ref` and checks out
   that ref in `code_checking` (otherwise uses `origin/main`).
3. Consumer workflow runs `bash ./code_checking/bin/run-linters.sh`.
4. Runner verifies the current `code_checking` checkout matches the desired
   ref, then performs changed-file linter selection and execution.

### Pre-commit Flow

1. Pre-commit resolves hook entry from this repository hook definition.
2. Hook entry runs `bash ./bin/run-linters.sh --mode changed`.
3. Runner verifies desired `code_checking` ref first.
4. Runner selects applicable linters for changed files and executes only those.

### Script and Directory Responsibilities

- `bin/run-linters.sh` and `bin/run-linters.ps1`:
  top-level orchestration entrypoints for CI, local, and pre-commit runs.
- `checks/ensure-code-checking-ref.sh` and
  `checks/ensure-code-checking-ref.ps1`:
  non-mutating verification that checkout matches `.code-checking-ref`
  (or `origin/main` by default).
- `checks/detect-linters.sh` and `checks/detect-linters.ps1`:
  changed-file analysis and linter selection.
- `checks/ensure-linter-tools.sh`:
  centralized executable preflight check for selected linters.
- `checks/linters/<linter>/run.sh` and `run.ps1`:
  per-linter executors that apply file filtering and invoke the tool.
- `.pre-commit-hooks.yaml`:
  exported hook definitions used by consumer repositories.
- `.pre-commit-config.yaml`:
  local repository pre-commit configuration for development and validation.

Design goals:

- One stable invocation surface for CI and pre-commit.
- Non-mutating validation checks by default.
- Dynamic linter selection based on actual changed files.
- Consumer repositories do not need hardcoded submodule directory names.
