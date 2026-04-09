# Maintenance Notes

This document contains maintainer-oriented planning notes that are kept out of
the primary usage README.

## Repository Rules and Branch Protection

This repository requires a status check to pass before merging pull requests.

### Overview

The `basic-source-checks` job from the `checks.yml` workflow is configured as a
required status check. This consolidates all code quality gates:

- `.code-checking-ref` guard — blocks accidental commits of local overrides
- Executable mode verification — ensures scripts have correct git index mode
- Dynamic linter selection and execution — runs applicable linters
  (shellcheck, etc.)

This consolidation avoids coupling branch protection rules to per-linter checks.
All rules are enforced in a single, stable status check.

### Setup (GitHub Web UI)

GitHub's repository settings interface has been reorganized multiple times.
This section describes the underlying structure; exact interface paths may vary.

**Locate the ruleset configuration:**

1. Navigate to repository Settings (gear icon in top-right menu).
2. Look for "Branches" or "Rules" in the left sidebar. GitHub has two
   overlapping systems:
   - **Branches** (older): Protection rules per-branch
   - **Rules** (newer): Rulesets with target patterns
3. If both exist, prefer **Rules** (rulesets) for new configurations.

**Create or edit the rule for `main`:**

1. Create a new ruleset or branch protection rule for the `main` branch.
2. Configure the following under "Status checks":
   - **Required status check**: Select `Basic Source checks`
   - Rulesets: appears under "Require status checks to pass"
   - Branch protection: appears under "Require status checks to pass before
     merging"
3. (Optional) Enable other protections:
   - **Pull Request Reviews**: "Require a pull request before merging"
   - **Dismiss stale reviews**: Reviews approved before a commit is pushed are
     dismissed
   - **Require review from code owners**: If you maintain `CODEOWNERS`
4. Save the rule.

**Verification:**

Once configured, attempts to merge a PR will fail with:

- "`Basic Source checks` – required check"

if any of the check steps fail (guard, executable modes, or linters).

### Testing the Configuration

**To verify the guard works:**

1. Create a test branch from `main`.
2. Create a local `.code-checking-ref` file with content: `origin/some-branch`
3. Commit and push:

   ```bash
   git add .code-checking-ref
   git commit -m "test guard"
   git push
   ```

4. Create a PR against `main`.
5. Verify GitHub shows `Basic Source checks` failing with guard error.
6. Verify the PR cannot be merged (merge button is disabled).

The GitHub Actions job will show:

```text
[guard-code-checking-ref] tracked file detected in commit: .code-checking-ref
```

To clean up, force-push without the test commit:

```bash
git reset HEAD~1 --hard
git push --force-with-lease
```

## Initial Consumer Targets

- ansible-lab
- system-pipeline-lib

## Planned Content Areas

- Shell and PowerShell check runners
- Check script library (ansible-lint, yamllint, shellcheck, markdownlint,
  groovylint, codespell)
- IDE setup baselines and a master IDE-agnostic YAML input (with VS Code
  section)
