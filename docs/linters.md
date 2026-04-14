# Linters

This repository exposes shared linter entrypoints intended to be called either:

- from this repository root while developing the checker library directly, or
- from a consumer repository root through the submodule path.

**Note:** When running shell scripts from the Visual Studio Code integrated
terminal, prefix with `bash` to use WSL or Git Bash (for example,
`bash ./bin/run-linters.sh`). Similarly, use `python` to invoke Python
scripts with the Windows Python instance.

## Path Model

The linter runner uses two roots:

- Library root: derived from the location of the script in this repository.
- Target root: the repository being checked.

By default, the target root is the current working directory. That means the
same pattern works in both contexts:

```bash
./bin/run-linters.sh
```

```bash
./code_checking/bin/run-linters.sh
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

## Current Linters

The changed-file linter set currently includes:

- `codespell` (text spelling and typo checks, including filenames)
- `text-hygiene` (trailing whitespace and missing final newline)
- `filename-portability` (non-ASCII filename guard)
- `shellcheck` (shell script linting for `*.sh`)

Current exclusions:

- `<actual-submodule-path>/*` (the library code itself in consumer repos)

### Pre-commit Integration

Consumer repositories can add this repository's hooks to their
`.pre-commit-config.yaml`:

```yaml
repos:
  - repo: https://github.com/daos-do/code-checking
    rev: main
    hooks:
      - id: shellcheck
```

Local pre-commit runs will then use the changed-file mode automatically.
Before running selected linters, the runner verifies that `code_checking` is
at the desired commit resolved from `.code-checking-ref` (or the submodule git
link recorded in the consumer repository HEAD when that file is missing). The
check is non-mutating and fails with sync commands if the checkout does not
match.
The runner also performs a centralized tool preflight check so required linter
executables are present before individual linter scripts run.

For local debugging with hook parity, run this single command from the
repository root:

```bash
./bin/run-pre-commit-checks.sh
```

This runs the same checks as commit hooks in order:

- `forbid tracked .code-checking-ref`
- `verify executable modes`
- `basic source linters`

To apply available auto-fixes:

```bash
./bin/run-pre-commit-checks.sh --fix
```

PowerShell equivalent:

```powershell
pwsh -File .\bin\run-pre-commit-checks.ps1
pwsh -File .\bin\run-pre-commit-checks.ps1 --fix
```

Current tool preflight mapping:

- `shellcheck` linter requires `shellcheck` executable on PATH
- `codespell` linter requires `codespell` executable on PATH

On Linux/macOS targets, preflight failures include install hints for common
package managers.

### Spelling-Friendly Naming

For new shell variable names and labels, prefer underscore-separated words when
possible so cspell can recognize components without whitelist growth.

Add words to the project dictionary only for stable domain terms that cannot
be split naturally.

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

## Adding a New Linter

Adding a linter currently requires touching multiple files.
That is intentional for now: installation, local runs, pre-commit behavior,
and CI all need to stay explicit and reviewable.

### Minimum integration checklist

For a new linter such as `codespell`, review and update these areas:

1. Detection

- `checks/detect-linters.sh`
- `checks/detect-linters.ps1`

Add selection logic so the linter is chosen for the relevant changed files.

1. Orchestration

- `bin/run-linters.sh`
- `bin/run-linters.ps1`

Add a dispatch case that calls the per-linter runner.

1. Per-linter executor

- `checks/linters/<linter>/run.sh`
- `checks/linters/<linter>/run.ps1`

Implement the actual file filtering and tool invocation in `run.sh`.
Keep `run.ps1` as a thin wrapper that delegates to `run.sh` via
`checks/invoke-bash.ps1`.

1. Tool preflight

- `checks/ensure-linter-tools.sh`

Add PATH checks and install hints for the required executable.

1. CI environment

- `.github/workflows/checks.yml`

Install the tool in the workflow job that runs the shared linter entrypoint.

1. Pre-commit integration

- `.pre-commit-hooks.yaml`
- `.pre-commit-config.yaml`

Usually the shared `bin/run-linters.sh` hook remains the same, but confirm the
hook metadata still matches the broadened linter set.

1. Documentation

- `docs/linters.md`
- `docs/usage.md`
- `bin/setup-dev.sh` / `bin/setup-dev.ps1` if install guidance changes there

Document what the linter checks, what tool must be installed, and any platform
or packaging expectations.

1. Optional config files

If the linter needs repository policy/config files, add them explicitly and
document how they are copied or used by consumers.

Examples:

- `.shellcheckrc`
- `.yamllint`
- future `codespell` ignore/config files if needed

### Example: codespell integration touched

The `codespell` addition required updates to:

- detection scripts
- top-level runners
- tool preflight
- CI install step
- per-linter `run.sh` and `run.ps1`
- linter documentation

That is normal under the current explicit model.

### Why not full drop-in auto-discovery yet?

A fully automatic model where a linter is enabled by dropping one script into a
directory is attractive, but it pushes complexity into the infrastructure.

The repository still needs to answer these questions explicitly:

- How is the linter selected from changed files?
- How is the required tool installed in CI?
- How do local users know what to install?
- How do preflight failures give the right install hint?
- Does the linter need config files or IDE integration?

Until those pieces are standardized further, explicit wiring is easier to
review and usually easier to maintain.

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

### Auto-Fix Mode

Selected checks support `--fix` to automatically correct certain issues.

#### Local Manual Runs

Use `--fix` from the command line:

```bash
./bin/run-pre-commit-checks.sh --fix
./checks/verify-executable-modes.sh --target-root . --fix
./bin/run-linters.sh --target-root . --mode changed --fix
```

Current fix coverage:

- `run-linters.sh --fix`: also applies `verify-executable-modes.sh --fix`
- `verify-executable-modes.sh`: applies `git add --chmod=+x` for shebang files
- `text-hygiene`: trims trailing whitespace and adds final newline where missing

#### Pre-commit Hooks

By default, pre-commit hooks run **without** auto-fix (violations are reported
but not corrected).

To enable auto-fix in your `.pre-commit-config.yaml`, add `args: [--fix]` to
the hook:

```yaml
repos:
  - repo: https://github.com/daos-do/code-checking
    rev: main
    hooks:
      - id: shellcheck
        args: [--fix]
      - id: verify-executable-modes
        args: [--fix]
```

When enabled, the hooks will:

- Report violations (as usual)
- Auto-correct fixable issues and stage them via `git add`
- Exit with success if all issues were corrected
- Exit with failure if unfixable violations remain

This allows developers to opt into automatic cleanup on commit rather than
having it happen by default.

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
