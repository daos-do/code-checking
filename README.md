# code_checking

Shared linting, check, and IDE bootstrap assets for this and other repositories.

This repository is designed to be consumed as a git submodule.
Consumer repositories add it as a top-level `code_checking/` directory and
keep local wrapper scripts and `.github/workflows` in their own tree.

## Goals

- Provide reusable, generic check scripts across repositories
- Keep check behavior consistent for CLI, pre-commit, and GitHub Actions
- Provide IDE baseline guidance and profile overlays
- Reduce duplicate checker logic and drift between repositories

## Non-Goals

- No private or environment-specific bootstrap logic
- No repository-specific ownership of `.github/workflows`
- No implicit source rewrites during commit checks

## Repository Policy

- License: Apache License 2.0
- Visibility: Public
- Primary maintainer group: DAOS-DO/Developers

## Checker Behavior Policy

- Checks are non-mutating by default.
- Commit-hook checks must report failures, not rewrite source files.
- Auto-fix behavior, if provided, must be explicit opt-in commands and must
  not run automatically inside commit hooks.

## Submodule Usage

Add this repository as a top-level submodule in a consumer repository:

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

## Initial Consumer Targets

- `ansible-lab`
- `system-pipeline-lib`

## Planned Content Areas

- Shell and PowerShell check runners
- Check script library (ansible-lint, yamllint, shellcheck, markdownlint,
  groovylint, codespell)
- IDE setup baselines and profile overlays for VS Code

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
