# Maintenance Notes

This document contains maintainer-oriented planning notes that are kept out of
the primary usage README.

## Repository Rules and Branch Protection

This section documents how required status checks and branch protection are set
up for this public repository. It is intended to help maintainers who may not
regularly manage GitHub repository rules and need to configure or verify the
merge protections used here.

### Overview

The following jobs are configured as required status checks:

- `Basic Source checks` from `checks.yml`
- `DCO / Signed-off-by` from `dco-signoff.yml`

`Basic Source checks` consolidates code quality gates:

- `code-checking-ref` guard — blocks accidental commits of local overrides
- Executable mode verification — ensures scripts have correct git index mode
- Dynamic linter selection and execution — runs applicable linters
  (shellcheck, etc.)

This consolidation avoids coupling branch protection rules to per-linter checks.
The separate DCO check enforces `Signed-off-by:` commit trailer policy.

### Setup (GitHub Web UI)

GitHub's repository settings interface has been reorganized multiple times.
This section describes the underlying structure; exact interface paths may vary.

**Locate the ruleset configuration:**

1. Navigate to repository Settings (gear icon in top-right menu).
2. Look for "Branches" or "Rules" in the left sidebar. GitHub has two
   overlapping systems:
   - **Branches** (older): Protection rules per-branch
   - **Rules** (newer): Rulesets with target patterns
3. For this repository, **Rules** (rulesets) is the managed path and source of
   truth; **Branches** settings are not used.

**Create or edit the rule for `main`:**

1. Create or edit the ruleset that targets the `main` branch.
   We use the name `protect-main`.
2. Set the ruleset-level **Bypass list** to **Organization admin** with bypass
   mode `For pull requests only`.
3. Under Branch targeting criteria, use `Default`.
4. Enable these branch rules:
   - **Restrict deletions**
   - **Require signed commits** (optional)
      - Enable only when all contributors are set up for verified commit
        signing (GPG/SSH/S/MIME).
   - **Require a pull request before merging**
       - **Required approvals**: 1
       - **Dismiss stale pull request approvals when new commits are pushed**
       - **Require review from Code Owners**
       - **Require conversation resolution before merging**
       - **Allowed merge methods**: disable merge commits; allow squash and
         rebase merges
   - **Require status checks to pass**
         - **Status checks that are required**:
            - `Basic Source checks`
            - `DCO / Signed-off-by`
      - GitHub does not make this selectable until the workflow exists on the
        default `main` branch.
   - **Block force pushes**

**Verification:**

Once configured, attempts to merge a PR will fail with:

- "`Basic Source checks` – required check"
- "`DCO / Signed-off-by` - required check"

if any of the check steps fail.

### Testing the Configuration

**To verify the guard works:**

1. Create a test branch from `main`.
2. Create a local `code-checking-ref` file with content: `pull/123/head`
   (or any valid git ref)
3. Commit and push:

   ```bash
   git add code-checking-ref
   git commit -m "test guard"
   git push
   ```

4. Create a PR against `main`.
5. Verify GitHub shows `Basic Source checks` failing with guard error.
6. Verify the PR cannot be merged (merge button is disabled).

The GitHub Actions job will show:

```text
[guard-code-checking-ref] tracked file detected in commit: code-checking-ref
```

To clean up:

- Close the test PR if it is no longer needed.
- If you want to keep using the branch for other changes, remove
   `code-checking-ref`, commit that removal, and push the update.

## Repository Automation Settings

This section documents repository-level automation settings that are configured
in GitHub Settings (not only in tracked files).

### Dependabot Enablement Scope

Dependabot should be enabled for this repository with a focused scope:

- `github-actions` updates for workflow action versions in
   `.github/workflows/*.yml`.

### Recreate and Verify Dependabot Settings

Use this runbook when bootstrapping a new repository host instance or auditing
for uncoordinated settings changes.

#### Source of Truth

- File-based Dependabot update behavior is defined in
  `.github/dependabot.yml`.
- Repository UI security toggles and alert auto-dismiss rules are manual
  settings and must be verified in GitHub Settings.

#### Dependabot Version Updates UI Note

The GitHub Security settings page shows a **Dependabot version updates** entry
with an "Enable" button. This is **not a toggle**. It is a status indicator
that reflects whether `.github/dependabot.yml` exists in the repository.
Clicking "Enable" starts a wizard to create that file via the GitHub web
editor. Do not use the wizard — the file is tracked in this repository and
managed via normal pull requests. If the indicator shows "Disabled", the file
is missing and should be restored from version control.

#### Setup Steps (GitHub Web UI)

1. Open repository Settings.
2. Open Security and quality, then Advanced Security (section labels may
   change over time).
3. Enable Dependabot alerts.
4. Enable Dependabot security updates.
5. Enable grouped security updates.
6. Do not change the **Dependabot version updates** setting in the UI. It only
   reports whether `.github/dependabot.yml` exists on the default `main`
   branch. If it is missing, add or restore the file through a pull request.

#### Expected Manual Alert Rule State

Record and periodically verify these manual settings in the Dependabot alert
rules UI:

- Dismiss low-impact alerts for development-scoped dependencies: enabled.
- Dismiss package malware alerts: disabled. Malware scanning is a paid GitHub
  feature not available on the free tier. Leave disabled unless the repository
  moves to a paid plan or GitHub Enterprise with that feature licensed.

If these values are changed, update this document in the same PR with rationale
and reviewer sign-off.

#### Verification Checklist

At audit time, verify all of the following:

1. `.github/dependabot.yml` exists and matches expected policy.
2. Dependabot alerts and security updates are enabled in repository settings.
3. Manual alert rule toggles match this document.
4. Dependabot is producing update PRs for `github-actions` when updates are
   available.

Initial scope is intentionally limited to workflow actions because those are
the repository-managed dependencies with the highest supply-chain relevance.
Expand scope later only when additional dependency manifests are intentionally
tracked and maintained in this repository.

### Why This Scope

- Keeps workflow action updates visible and reviewable via PRs.
- Reduces manual drift risk for action versions.
- Avoids noisy update churn for ecosystems not centrally managed in this repo.

### GitHub Actions Version Pinning Policy

- Workflow `uses:` entries are pinned to full commit SHAs.
- This is required to satisfy OpenSSF Scorecard `Pinned-Dependencies` checks.
- Include the corresponding version tag as an inline YAML comment when useful
   for readability (for example, `# v6.0.2`).

### Manual Review Cadence

At least quarterly, maintainers should:

1. Verify Dependabot is enabled for `github-actions` and opening update PRs.
2. Review all workflow action versions in `.github/workflows/*.yml`.
3. Check release notes for major actions used here (at minimum
   `actions/checkout`).
4. Update SHA pins as needed and run full local checks before merging:

   ```bash
   ./bin/run-linters.sh --mode full
   ./bin/run-checks.sh
   ```

5. Reconfirm branch/ruleset protections still require `Basic Source checks`.

## Initial Consumer Targets

- ansible-lab
- system-pipeline-lib

## Planned Content Areas

- Shell and PowerShell check scripts
- Check script library (ansible-lint, yamllint, shellcheck, markdownlint,
  groovylint, codespell)
- IDE setup baselines and a master IDE-agnostic YAML input (with VS Code
  section)
