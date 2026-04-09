# Developer Customization Design

This document describes the current local customization model with one
human-maintained YAML file as input.

## Goals

- Keep one master input file for team readability.
- Remove profile-file indirection from user customization.
- Keep local user customization out of version control.
- Keep setup cross-platform with one Python engine and thin shell wrappers.

## Core Decision

Use a single YAML customization file.

- Reference file (committed): `ide/reference/recommended_settings.yml`
- Optional local user file (untracked): `./local_ide_settings.yml`

No profile selection is required in user config. Users edit final desired
settings directly in YAML, under IDE-specific sections.

## File Layout

Committed files:

- `ide/reference/recommended_settings.yml`
- `bin/ide-workspace-setup.py`
- `bin/ide-workspace-setup.ps1`
- `bin/ide-workspace-setup.sh`

Optional untracked local file:

- `local_ide_settings.yml`

Tracked ignore rule:

```gitignore
/local_ide_settings.yml
```

## YAML Contract (v1)

Top-level keys:

- `ide`
- `linting`
- `preCommit`
- `packageSources`

Current IDE section:

- `ide.vscode`

Future IDE sections may be added by maintainers (for example, `ide.intellij`).

Minimal example:

```yaml
---
ide:
  vscode:
    settings: {}
    extensions:
      recommendations: []

linting:
  profiles: []

preCommit:
  mode: selected

packageSources:
  allowUncertifiedSources: false
  allowedSources: []
```

Practical example:

```yaml
---
ide:
  vscode:
    settings:
      editor:
        formatOnSave: false
      files:
        associations:
          LICENSE: plaintext
          NOTICE: plaintext
    extensions:
      recommendations:
        - redhat.ansible
        - redhat.vscode-yaml

linting:
  profiles: []

preCommit:
  mode: selected

packageSources:
  allowUncertifiedSources: false
  allowedSources: []
```

## Setup Behavior

`bin/ide-workspace-setup.py` reads config in this order:

1. `./local_ide_settings.yml` in current working directory (if present)
2. otherwise `ide/reference/recommended_settings.yml`

Execution model:

- Run from consumer repository root when this repository is used as a submodule.
- Run from this repository root when developing this repository directly.
- Use the chosen submodule directory name as path prefix for scripts and
  reference files in commands.

Processing behavior:

- Baseline VS Code settings and extension recommendations are loaded from
  `ide/reference/recommended_settings.yml`.
- The selected YAML config (`./local_ide_settings.yml` when present, otherwise
  the reference file) is merged on top of baseline values.
- Existing `.vscode/extensions.json` recommendations are preserved, and YAML
  recommendations are appended with deduplication.

Outputs:

- `.vscode/settings.json`
- `.vscode/extensions.json`
- `cspell.config.yaml` if missing
- `vscode-project-words.txt` if missing
- Missing root-level linter/config files copied from the shared repository

## Validation

Current strict validation:

- YAML root must be a mapping.
- `ide` must be a mapping.
- `ide.vscode.settings` must be a mapping.
- `ide.vscode.extensions.recommendations` must be a list.
- `linting.profiles` must be a list.
- `preCommit.mode` must be one of: `selected`, `none`, `all`.
- `packageSources.allowUncertifiedSources` must be boolean.
- `packageSources.allowedSources` must be a list.

## Dependency Note

The setup engine uses `PyYAML`.

On Windows, invoke `bin/ide-workspace-setup.py` explicitly with `python`.
Do not rely on `.py` file association, because it may be unset or may select
an interpreter outside the intended environment.
Use `bin/ide-workspace-setup.sh` for non-Windows shells.

If missing, install using your platform's package manager:

**macOS:**

```bash
brew install pyyaml
```

**Debian/Ubuntu:**

```bash
sudo apt install python3-yaml
```

**RPM-based (RHEL, CentOS, Fedora):**

```bash
sudo dnf install python3-pyyaml
```

**Windows:**

```cmd
python -m pip install pyyaml
```

## Why This Model

- Easier for humans to review and maintain.
- One file contains both guidance and active configuration structure.
- Supports future IDE sections without changing the input-file model.
- YAML comments enable inline team guidance without external indirection.
