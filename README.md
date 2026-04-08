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
- Commit-hook checks must report failures, not rewrite source files.
- Auto-fix behavior, if provided, must be explicit opt-in commands and must
  not run automatically inside commit hooks.

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
git add code_checking
git commit -m "Update code_checking submodule"
```

Consumer repositories keep:

- Local wrapper scripts or entrypoints at their expected local paths
- Local `.github/workflows` definitions

Shared scripts in this repository are invoked by those local wrappers and
workflows.

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

Configuration model details are in
[docs/ide-customization.md](docs/ide-customization.md).

## Cross-Repo Reuse

Checkers are implemented with stable, repo-agnostic interfaces to minimize
changes when sharing with other repositories. Repository-specific assumptions
belong in local wrappers or config files, not in shared checker logic.

## Change Workflow

1. Issue found in a consumer repository.
2. Fix submitted to `code_checking` via PR.
3. After merge, consumer repository updates its submodule reference via PR.
4. Consumer CI validates integration.

## Status

Initial repository bootstrap.
Content will be populated as checks and IDE assets are migrated from
consumer repositories.
