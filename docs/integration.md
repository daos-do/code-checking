# Integration

Consumer repositories should add this repository as a top-level submodule:

```bash
git submodule add https://github.com/daos-do/code-checking code_checking
git submodule update --init --recursive
```

Consumer repositories keep local wrappers and workflow files and call shared
scripts from `code_checking/`.

For bootstrap and validation flows, use the consumer sync command after adding
the submodule, updating it, or changing `code-checking-ref`.

Linux/macOS:

```bash
./code_checking/bin/sync-consumer.sh
```

PowerShell equivalent:

```powershell
pwsh -File .\code_checking\bin\sync-consumer.ps1
```

To skip README updates for a specific run:

Linux/macOS:

```bash
./code_checking/bin/sync-consumer.sh --skip-readme
```

PowerShell equivalent:

```powershell
pwsh -File .\code_checking\bin\sync-consumer.ps1 -SkipReadme
```

See [README.md](../README.md) for details on what `sync-consumer` does.

Optionally, you can manually sync or validate the recommended GitHub workflow
(see [README.md](../README.md) for details on `setup-github-workflow.sh`).

## Initial Consumer Commit

After the bootstrap commands above have run, stage only the consumer-side
files for the initial commit. Do not stage the `code_checking` submodule
pointer if it is currently checked out at a PR or test ref.

First verify the submodule pointer is at `origin/main`:

```bash
# Should match:
git -C code_checking rev-parse HEAD
git ls-remote origin refs/heads/main | awk '{print $1}'
```

If the submodule is at a test ref, reset it to `origin/main` before
committing:

```bash
git -C code_checking fetch origin
git submodule update --remote code_checking
```

For the staging and commit details, see
[README.md](../README.md#initial-consumer-commit).

Do not stage `code-checking-ref` for normal integration commits. It will
usually remain visible in `git status` as an untracked file. The pre-commit
guard hook blocks accidental commits of it. An intentional validation PR may
track it temporarily when testing a `code_checking` PR ref.

## Consuming Submodule Force-Push Updates

There are two distinct cases: updating to a force-pushed code_checking PR
branch while testing it locally, and updating the submodule to a new main
tip after a merge.

### Case 1: Testing a Force-Pushed code_checking PR

This is the case where you have `code-checking-ref` set to a PR branch
and that PR was force-pushed. `git submodule update --remote` is not
sufficient here because it does not know to reset to the new force-pushed
commits; you need to fetch and hard-reset.

1. Find the branch name in `code-checking-ref`.

  ```bash
  cat code-checking-ref
  # example output: sre-3706-codespell
  ```

1. Fetch the updated branch from the submodule remote.

  ```bash
  git -C code_checking fetch origin sre-3706-codespell
  ```

1. Reset the submodule checkout to the fetched branch tip.

  ```bash
  git -C code_checking reset --hard origin/sre-3706-codespell
  ```

1. Verify git status.

  ```bash
  git status
  # modified:   code_checking (new commits)  <-- do not stage this
  ```

  The submodule will show as modified (new commits), but do not stage or
  commit it. Keep the submodule pointer at the commit already recorded in
  the consumer PR.

1. If the code_checking PR changed linter/tool requirements, regenerate the
  consumer workflow.

  ```bash
  ./code_checking/bin/setup-github-workflow.sh --apply
  ```

1. Stage and commit only the changed workflow file.

  ```bash
  git add .github/workflows/basic-source-checks.yml
  git commit --amend --no-verify
  ```

Use `--no-verify` only if your consumer PR intentionally tracks
`code-checking-ref` and the guard hook fires on it.
The `--no-verify` bypass is acceptable here because the guard hook is
protecting against accidental commits; the PR is intentional.

For routine updates to a new main tip, see
[README.md](../README.md#update-to-latest).

For background on submodule update behavior and remote-tracking refs, see the
official Git documentation:

- [git submodule docs](https://git-scm.com/docs/git-submodule)
- [git fetch docs](https://git-scm.com/docs/git-fetch)

## Scope

This document currently defines workflow behavior for GitHub Actions only.
Jenkins-specific behavior is intentionally out of scope.

## GitHub Actions Submodule Policy

For consumer repositories, the convention is:

1. Default: use the tip of `main` for `code_checking`.
2. Optional override: allow a root file named `code-checking-ref` to
  temporarily select a PR ref or specific commit for validation. In normal
  use it remains untracked locally; in an intentional validation PR it may be
  tracked temporarily.
3. Do not require pinning `code_checking` to a specific commit in the consumer
   repository for normal operation.

This policy minimizes cross-repository update churn while still allowing
pre-merge validation when needed.

Local pre-commit runs use the same desired-ref policy. They verify (without
changing files) that `code_checking` is checked out at the commit resolved from
`code-checking-ref` (or `origin/main` when the file is absent).

## Prerequisites

For consumers using pre-commit hooks, ensure `pre-commit` is installed:

```bash
# macOS (Homebrew)
brew install pre-commit

# Debian/Ubuntu
sudo apt-get install pre-commit
```

On Linux, prefer distro package managers and avoid `sudo pip install` for
system tools, because it can conflict with distro-managed Python packages.

If local pre-commit hooks are desired, run setup from the consumer repository
root:

```bash
./code_checking/bin/setup-dev.sh
```

PowerShell equivalent:

```powershell
pwsh -File .\code_checking\bin\setup-dev.ps1
```

This local setup step is not required for GitHub Actions.
`setup-dev` does not create or update `.github/workflows` files.
When run from a consumer repository, `setup-dev` installs hooks in the consumer
repository, not in the `code_checking` submodule. If
`.pre-commit-config.yaml` is missing, `setup-dev` bootstraps a baseline config
that uses `./code_checking` hook entrypoints and then installs hooks.

## GitHub Actions Checkout Behavior

GitHub Actions must fetch submodule contents explicitly in checkout steps.
Use `actions/checkout` with submodules enabled.

Recommended behavior for consumer workflows:

- Default to `origin/main` for `code_checking`
- If `code-checking-ref` exists, resolve and use that ref instead
- Do not rely on the commit pinned in the submodule pointer for checks

Example:

```yaml
- uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd # v6.0.2
  with:
    submodules: recursive
    fetch-depth: 0

- name: Resolve code_checking ref
  run: |
    REF="origin/main"
    if [ -f code-checking-ref ]; then
      REF="$(grep -v '^[[:space:]]*#' code-checking-ref |
             sed '/^[[:space:]]*$/d' | head -n 1)"
    fi
    if [ -z "${REF}" ]; then REF="origin/main"; fi
    case "${REF}" in
      refs/*) FETCH_REF="${REF}" ;;
      origin/*) FETCH_REF="refs/heads/${REF#origin/}" ;;
      pull/*/head|pull/*/merge) FETCH_REF="refs/${REF}" ;;
      *) FETCH_REF="refs/heads/${REF}" ;;
    esac
    git -C ./code_checking fetch origin "${FETCH_REF}"
    git -C ./code_checking checkout FETCH_HEAD
```

## Preventing Accidental PR and Jenkins Override Landings

Recommended guardrail for consumer repositories:

1. Use the same guard script in both pre-commit and GitHub Actions:
  `./code_checking/checks/guard-code-checking-ref.sh`.
2. Add a Jenkins landing guard in GitHub Actions:
  `./code_checking/checks/guard-jenkins-library-pin.sh`.
3. Add guard steps in the same workflow job that runs shared checks.
4. Let guards record failure without stopping later checks, then fail the
  job at the end if the guard tripped.
5. Require only that single stable checks job in repository rules.

Example step:

```bash
./code_checking/checks/guard-code-checking-ref.sh --target-root .
./code_checking/checks/guard-jenkins-library-pin.sh --target-root .
```

This allows normal local override usage while still allowing intentional
validation PRs that temporarily track `code-checking-ref`, without hiding the
results of later checks. It also blocks active Jenkins shared-library
references such as `@Library("my-shared-lib") _` from landing. Guards still
leave the final job status failed so the PR cannot merge accidentally.

Example GitHub Actions job:

```yaml
jobs:
  basic-source-checks:
    name: Basic Source checks
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd # v6.0.2
        with:
          submodules: recursive
          fetch-depth: 0
      - name: Resolve code_checking ref
        run: |
          REF="origin/main"
          if [ -f code-checking-ref ]; then
            REF="$(grep -v '^[[:space:]]*#' code-checking-ref |
                   sed '/^[[:space:]]*$/d' | head -n 1)"
          fi
          if [ -z "${REF}" ]; then REF="origin/main"; fi
          case "${REF}" in
            refs/*) FETCH_REF="${REF}" ;;
            origin/*) FETCH_REF="refs/heads/${REF#origin/}" ;;
            pull/*/head|pull/*/merge) FETCH_REF="refs/${REF}" ;;
            *) FETCH_REF="refs/heads/${REF}" ;;
          esac
          git -C ./code_checking fetch origin "${FETCH_REF}"
          git -C ./code_checking checkout FETCH_HEAD
      - name: Block tracked code-checking-ref
        id: guard_code_checking_ref
        continue-on-error: true
        run: |
          bash ./code_checking/checks/guard-code-checking-ref.sh \
            --target-root .
      - name: Block active Jenkins @Library reference
        id: guard_jenkins_library_pin
        continue-on-error: true
        run: |
          bash ./code_checking/checks/guard-jenkins-library-pin.sh \
            --target-root .
      - name: Verify executable modes
        run: |
          bash ./code_checking/checks/verify-executable-modes.sh \
            --target-root .
      - name: Run shared linters
        run: bash ./code_checking/bin/run-linters.sh
      - name: Fail if any guard check failed
        if: >-
          ${{ always() &&
              (steps.guard_code_checking_ref.outcome == 'failure' ||
               steps.guard_jenkins_library_pin.outcome == 'failure') }}
        run: exit 1
```

### Repository Rules Setup (GitHub Web UI)

Configure branch protection to require the shared checks before merging.

**Locate the ruleset configuration in your consumer repository:**

1. Navigate to repository Settings (gear icon in top-right menu).
2. Look for "Branches" or "Rules" in the left sidebar. GitHub has two
   overlapping systems:
   - **Branches** (older): Protection rules per-branch
   - **Rules** (newer): Rulesets with target patterns
3. If both exist, prefer **Rules** (rulesets) for new configurations.

**Create or edit the rule for your merge branch (for example `main`):**

1. Create a new ruleset or branch protection rule for your merge branch.
2. Configure the following under "Status checks":
   - **Required status check**: Select `Basic Source checks` (from shared
     workflow)
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

if any check steps fail (guard, executable modes, or linters).

**Optional test (guard behavior):**

- Create a test PR that intentionally tracks `code-checking-ref`
- Verify merge is blocked by the required check

To validate override behavior locally, bypass pre-commit checks with:

```bash
git commit --no-verify
```

The required GitHub check still prevents accidental merge to your protected
branch.

## Validating Fixes Before PR Merge

When validating a `code_checking` pull request from a consumer repository,
create or update `code-checking-ref` in the consumer repository root with the
desired ref value.

Supported values can be any ref accepted by `git checkout`, such as:

- `origin/main`
- `pull/123/head`
- `feature/some-branch`
- a commit SHA

Suggested validation flow:

1. Set `code-checking-ref` to the PR ref (for example `pull/123/head`).
2. Run `./code_checking/bin/sync-consumer.sh` from the consumer repo root.
3. Commit the resulting consumer-repo changes if needed (for example workflow
  updates or submodule pointer changes).
4. Run checks and validate behavior.

PowerShell equivalent:

```powershell
pwsh -File .\code_checking\bin\sync-consumer.ps1
```

Local pre-commit validation uses the same ref value. If you need a manual
fallback, sync your local checkout first:

```bash
REF="$(grep -v '^[[:space:]]*#' code-checking-ref |
       sed '/^[[:space:]]*$/d' | head -n 1)"
if [ -z "$REF" ]; then REF="origin/main"; fi
git -C code_checking fetch origin "$REF"
git -C code_checking checkout FETCH_HEAD
```

PowerShell equivalent:

```powershell
$ref = 'origin/main'
if (Test-Path -LiteralPath code-checking-ref) {
  foreach ($line in Get-Content -LiteralPath code-checking-ref) {
    $trimmed = $line.Trim()
    if (-not $trimmed) { continue }
    if ($trimmed.StartsWith('#')) { continue }
    $ref = $trimmed
    break
  }
}
git -C code_checking fetch origin $ref
git -C code_checking checkout FETCH_HEAD
```

Example workflow step after checkout:

```bash
if [ -f code-checking-ref ]; then
  REF="$(cat code-checking-ref)"
  git -C code_checking fetch origin "$REF"
  git -C code_checking checkout FETCH_HEAD
else
  git -C code_checking fetch origin main
  git -C code_checking checkout origin/main
fi
```

## After PR Merge

No consumer repository commit is required to return to normal operation if the
override file is not tracked.

To return to default behavior after validation:

1. Remove `code-checking-ref` (or set it to `origin/main`).
2. Re-run the GitHub workflow.
3. Confirm the workflow uses `origin/main` for `code_checking`.
