# Usage

## Local checks (shell)

```bash
bash bin/run-checks.sh
```

## Local checks (PowerShell)

```powershell
pwsh -File ./bin/run-checks.ps1
```

## Local setup (shell)

```bash
bash bin/setup-dev.sh
```

This script:

- Checks for pre-commit and shellcheck prerequisites
- Attempts to install missing tools via package managers first
- Initializes pre-commit hooks in your repository

For pre-commit hook usage, you need the pre-commit package.
On Linux, `setup-dev.sh` uses distro package managers only (apt/dnf/yum),
with no pip fallback.
On macOS, it prefers Homebrew and can fall back to user-scoped pip installs.

For Linux/macOS manual install, prefer your system package manager:

```bash
# macOS (Homebrew)
brew install pre-commit

# Debian/Ubuntu
sudo apt-get install pre-commit
```

Avoid `sudo pip install` on Linux because it can conflict with distro-managed
Python packages.

For linter execution, ensure linter executables are installed on PATH.
The linter runner performs a preflight check and fails early with install hints
when required tools are missing.

Current requirements:

- `pre-commit` for commit-hook integration
- `shellcheck` for shell linting

## Local setup (PowerShell)

```powershell
pwsh -File ./bin/setup-dev.ps1
```

This script checks for pre-commit and shellcheck prerequisites.
For Windows, run `bootstrap-windows-dev.ps1` first to install pre-commit and other tools.

## Local scratch files

Use a `zzz-` prefix for temporary local scratch files such as planning notes
and draft commit messages.

Examples:

- `zzz-next-review-plan.txt`
- `zzz-commit-messages.txt`

Root-level `zzz-*` files are ignored by the repository `.gitignore` and are not
intended to be committed.

## IDE customization design

See [docs/ide-customization.md](docs/ide-customization.md) for the
configuration model, YAML contract, and validation rules.

## VS Code extensions baseline

See [docs/vscode-extensions.md](docs/vscode-extensions.md) for recommendations
on which VS Code extensions to install, platform-specific requirements, and
optional external tool dependencies.

## VS Code spell checker

See [docs/vscode-cspell.md](docs/vscode-cspell.md) for guidance on using the
VS Code Code Spell Checker extension, including how to keep an IDE-only
project dictionary separate from `codespell` hook and CI configuration.

## IDE customization

Submodule usage model:

- Run from the base directory of the consumer repository clone.
- Prefix script and reference paths with your chosen submodule directory name.
- If you want to customize the recommended settings, keep an optional
  user-maintained file at `./local_ide_settings.yml` in the directory where
  setup is run.
- `./local_ide_settings.yml` is intentionally untracked and should not be
  committed.
- When working directly in this repository, drop the submodule path prefix
  on commands and paths.

Run the Windows bootstrap script (normally one-time per system; rerun when
validating or repairing tooling):

```powershell
.\code_checking\bin\bootstrap-windows-dev.ps1
```

The bootstrap script installs and configures:

- Git for Windows (via winget)
- Python 3 (via winget)
- PyYAML Python package (via pip)
- Global Git settings: `core.autocrlf=input`, `core.eol=lf`,
  `core.safecrlf=true`, `core.filemode=false`, `core.symlinks=false`,
  `core.longpaths=true`

The only prerequisite for the bootstrap script itself is `winget` (App
Installer), which is included with Windows 11 or available from the Microsoft
Store.

Note: Use one Git implementation per working tree on Windows. Do not alternate
writes between Git for Windows, WSL git, and other Git clients in the same
checkout because file mode, symlink, and path handling differences can
corrupt files or repository metadata.

Non-Windows shells can use `bootstrap-python.sh` to verify that Python 3 is
available before running setup.

```bash
bash ./code_checking/bin/bootstrap-python.sh
```

CI validation on Windows (no installs):

```powershell
.\code_checking\bin\bootstrap-windows-dev.ps1 -ValidateOnly
```

Copy template to local file if you want custom ide settings different than
the recommended settings. Note that you can remove settings or change values,
but the ide-workspace-setup.py script only knows about what settings are
in the recommended settings YAML file.

```bash
cp ./code_checking/ide/reference/recommended_settings.yml ./local_ide_settings.yml
```

Then edit `./local_ide_settings.yml` and adjust:

- `ide.vscode.settings` for workspace settings overrides
- `ide.vscode.extensions.recommendations` for extra extension recommendations
- `linting`, `preCommit`, and `packageSources` for local policy values

Setup command names:

- Windows: `python .\code_checking\bin\ide-workspace-setup.py` (dry run)
- Non-Windows shells: `bash ./code_checking/bin/ide-workspace-setup.sh` (dry run)
- Add `--apply` to perform a live write

Examples:

```powershell
python .\code_checking\bin\ide-workspace-setup.py
python .\code_checking\bin\ide-workspace-setup.py --apply
```

```bash
bash ./code_checking/bin/ide-workspace-setup.sh
bash ./code_checking/bin/ide-workspace-setup.sh --apply
```

Note: `ide-workspace-setup` merges into any existing `.vscode/settings.json`
rather than replacing it, so existing settings and word lists are preserved.
It also runs `code --install-extension` for each recommended extension.
Run from a VS Code integrated terminal or ensure `code` is on your PATH.
On Windows, use explicit `python ...\ide-workspace-setup.py` invocation.
Do not rely on `.py` file association, because it may be unset or may launch
an interpreter outside the intended VS Code or workspace Python environment.
Also avoid plain `bash` because it may accidentally run the setup through WSL.

### VS Code Python Interpreter Selection

After running `ide-workspace-setup` for the first time, VS Code may prompt you
to select a Python interpreter when you open a python or ansible file. This is
a one-time manual step:

1. Click "Select Interpreter" in the status bar or run
   `Python: Select Interpreter` from the Command Palette.
2. Choose your desired Python 3 installation from the list.
3. VS Code caches this selection in the workspace and will not prompt again.

Setup cannot pre-select the interpreter automatically because VS Code stores
interpreter selections in internal workspace state, and the correct path varies
by system and installation method.
