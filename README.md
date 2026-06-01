# code_checking

Shared linting, check, and IDE bootstrap assets for this and other repositories.

This repository exists to help the team implement coding practices they have
agreed on. Content is added here only after team agreement, typically through
the PR review process.

This repository is designed to be consumed as a git submodule.
Consumer repositories add it as a top-level `code_checking/` directory and
keep local wrapper scripts and `.github/workflows` in their own tree.

## Goals

- Provide reusable, generic check scripts across repositories
- Keep check behavior consistent for CLI, pre-commit, and GitHub Actions
- Provide IDE baseline guidance and a single YAML customization input
- Reduce duplicate checker logic and drift between repositories

## Non-Goals

- No private or environment-specific bootstrap logic
- No repository-specific ownership of `.github/workflows`
- No implicit source rewrites during commit checks

## Repository Policy

- License: Apache License 2.0
- Visibility: Public
- Primary maintainer group: DAOS-DO/Developers

## Local Scratch Files

- Repository-local scratch files should use a `zzz-` prefix.
- Scratch files are for temporary planning notes, draft commit messages, and
  similar local work in progress.
- Scratch files must not be committed to the repository.
- Root-level `zzz-*` files are ignored through the tracked `.gitignore` so
  `git status` stays focused on commit candidates.

## Checker Behavior Policy

- Checks are non-mutating by default.
- Commit-hook checks report failures without rewriting source files.
- Auto-fix behavior is available via explicit `--fix` opt-in for both local
  manual runs and pre-commit hooks, and is disabled by default.
- Auto-fix must never run automatically inside commit hooks; it requires
  explicit opt-in through hook configuration or command-line arguments.

See [docs/linters.md](docs/linters.md#auto-fix-mode) for auto-fix usage and
configuration details.

## Submodule Usage

Add this repository as a top-level submodule in a consumer repository:

- Commands in this README that reference `code_checking/` assume the submodule
  directory is named `code_checking`.
- If your submodule uses a different directory name, replace that path prefix
  in commands.
- Run submodule-integration commands from the consumer repository root.

```bash
git submodule add https://github.com/daos-do/code-checking code_checking
git submodule update --init --recursive
```

Update to latest:

```bash
git submodule update --remote code_checking
```

Consumer repositories keep:

- Local wrapper scripts or entrypoints at their expected local paths
- Local `.github/workflows` definitions

Shared scripts in this repository are invoked by those local wrappers and
workflows.

Local developer setup for pre-commit hooks is optional and separate from CI:

- In this repository: run `./bin/setup-dev.sh` (or
  `pwsh -File ./bin/setup-dev.ps1`) if you want local pre-commit hooks.
- In a consumer repository: run
  `./code_checking/bin/setup-dev.sh` (or PowerShell equivalent) from the
  consumer repo root for local hook setup. If `.pre-commit-config.yaml`
  is missing, setup bootstraps a baseline config that uses
  `./code_checking` hook entrypoints.
- Running linters in GitHub Actions does not require `setup-dev`.

`setup-dev` does not create or modify consumer `.github/workflows` files.

To bootstrap or refresh consumer-repository integration after adding the
submodule, updating it, or changing `code-checking-ref`, run:

Linux/macOS:

```bash
./code_checking/bin/sync-consumer.sh
```

PowerShell equivalent:

```powershell
pwsh -File .\code_checking\bin\sync-consumer.ps1
```

This command syncs the `code_checking` ref, writes the recommended GitHub
workflow (`pull_request` trigger only, to avoid duplicate `push` + PR runs),
bootstraps or refreshes pre-commit hooks, and updates the consumer `README.md`
managed section. It also seeds baseline `.gitignore`,
`cspell.config.yaml`, `.yamllint`, and `vscode-project-words.txt` in the
consumer root when those files are missing. Running `sync-consumer` means you
do not need to run `setup-github-workflow.sh` separately.

After `sync-consumer` completes, commit all integration files in a single commit
using the site commit message standards from
[docs/git-commit-message-guidelines.md](docs/git-commit-message-guidelines.md).
Example commit message format:

```text
TKT-XXXX: Add code-checking submodule integration

Integrated code-checking as a top-level submodule to provide shared linting
and check scripts across the repository. Bootstraps baseline workflows,
pre-commit hooks configuration, and IDE settings.

Consumer integration:
- Added .github/workflows with code-checking checks
- Configured pre-commit hooks to use code-checking entrypoints
- Seeded baseline configuration files (.yamllint, cspell.config.yaml, etc.)
- Updated README.md with code-checking managed section
```

To skip README updates for a specific run:

```bash
./code_checking/bin/sync-consumer.sh --skip-readme
```

For an initial consumer-repo integration commit after running
`sync-consumer`, stage all of these files together and commit with a proper
commit message following the site standards:

- `.github/workflows/` (may need to add newly created files instead)
- `.gitignore` (if seeded)
- `.gitmodules`
- `.pre-commit-config.yaml` (if `setup-dev` was run)
- `README.md`
- `cspell.config.yaml` (if seeded)
- `.yamllint` (if seeded)
- `vscode-project-words.txt` (if seeded)

The `code_checking` submodule directory itself should also be staged:

- `code_checking/`

The `code_checking` submodule was previously added. Changes inside that
directory are not required for this integration commit.

Example staging commands:

```bash
git add .github/workflows/
git add .gitignore
git add .gitmodules
git add .pre-commit-config.yaml
git add .pylint
git add .yamllint
git add code_checking
git add cspell.config.yaml
git add README.md
git add vscode-project-words.txt
```

Then commit with a proper message:

```bash
git commit
```

This will open your editor to write a commit message following the guidelines.

Do not stage `code-checking-ref` for normal integration commits. An
intentional validation PR may track it temporarily when testing a
`code_checking` PR ref.

To install or update only the recommended GitHub workflow without a full
submodule sync, run:

Linux/macOS:

```bash
./code_checking/bin/setup-github-workflow.sh --apply
```

PowerShell equivalent:

```powershell
bash .\code_checking\bin\setup-github-workflow.sh --apply
```

This keeps workflow ownership in the consumer repo while providing a shared
script to sync the recommended workflow after submodule add/update.

Shared linter entrypoints are available at `bin/run-linters.sh` and
`bin/run-linters.ps1`.
They resolve the library root from the script path and treat the current
working directory as the target repository root by default, which allows the
same command pattern to work both in this repository and from a consumer
repository that vendors this repository as a submodule.

Selected linters support `--fix` for automatic issue correction. Use
`./bin/run-linters.sh --fix` for manual runs, or configure pre-commit hooks
with `args: [--fix]` to enable auto-fix on commit. See
[docs/linters.md](docs/linters.md#auto-fix-mode) for details.

Maintenance planning notes are documented in
[docs/maintenance.md](docs/maintenance.md).

## IDE Customization

- Run commands from the base directory of the consumer repository clone.
- Use your chosen submodule directory name as the path prefix for scripts and
  reference files in this repository.
- If you want local overrides, keep an optional user-maintained file at
  `./local_ide_settings.yml` in the directory where setup is run.
- `./local_ide_settings.yml` is intentionally untracked and belongs in
  `.gitignore`; it should not be committed.
- Run the bootstrap script for your platform first, then run
  `ide-workspace-setup` in dry-run mode before `--apply`.
- If you are developing this repository directly rather than using it as a
  submodule, drop the `code_checking/` path prefix from commands.

Detailed usage is in [docs/usage.md](docs/usage.md).

Recommended VS Code extensions and platform-specific tool requirements are
documented in [docs/vscode-extensions.md](docs/vscode-extensions.md).

For shared spell-check dictionary updates in a consumer repository, use the
workflow in [docs/vscode-cspell.md](docs/vscode-cspell.md). The preferred VS
Code action is `Add to Workspace Dictionary`, which updates the repo-managed
`vscode-project-words.txt` file instead of user settings or
`.vscode/settings.json`.

Configuration model details are in
[docs/ide-customization.md](docs/ide-customization.md).

## Cross-Repo Reuse

Checkers are implemented with stable, repo-agnostic interfaces to minimize
changes when sharing with other repositories. Repository-specific assumptions
belong in local wrappers or config files, not in shared checker logic.

## Change Workflow

1. Issue found in a consumer repository.
2. Fix submitted to `code_checking` via PR.
3. Consumer validates from GitHub Actions using default `main` tip or an
  optional temporary ref override.
4. After merge, remove the temporary override (if used) and re-run CI.

For detailed instructions on testing fixes before merge and updating after
merge, see [docs/integration.md](docs/integration.md)
under "Validating Fixes Before PR Merge".

For required-status-check setup that blocks merges when `code-checking-ref`
is tracked, see
[docs/integration.md](docs/integration.md#repository-rules-setup-github-web-ui).

## Status

Initial repository bootstrap in progress.
Check scripts are in the progress of populated as checks and IDE assets
are migrated from consumer repositories.
