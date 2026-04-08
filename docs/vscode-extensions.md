# VS Code Extensions Baseline

This document catalogs the VS Code extensions initially used in this
project, their purposes, and platform-specific requirements.

The `ide/reference/recommended_settings.yml` has a list of the current
recommended settings. This document explains the baseline and platform notes.

**Scope:** IDE productivity and code quality tools. Docker/Podman
containerization is explicitly out of scope and excluded from this baseline.

## Extensions to Install Directly

These are the primary extensions recommended for all developers.
Install only these; their dependent extensions will be pulled in automatically.
Some extensions require specific software packages to be installed on the host.

### AI & Code Assistance

> **⚠ Important:** AI tools like GitHub Copilot may be subject to local
> site security policies, data residency requirements, or acceptable use
> policies. Verify compliance with your organization's IT and legal guidelines
> _before_ installing or using these extensions.
> **Configuring AI tools to meet local site requirements is outside the scope
> of this document.** Contact your site administrator or security team
> for guidance.

#### `github.copilot-chat`

- **Publisher:** GitHub
- **Purpose:** AI-powered code suggestions and conversations within the editor.
- **Platform Notes:**
  - Windows: Requires Windows Git to be installed for SSH key authentication.
  - macOS/Linux: SSH support included with native Git.
- **Related Dependencies:** None (stands alone; Copilot Chat does not
  require base Copilot).

### Language Support & Linting

#### `ms-python.python`

- **Publisher:** Microsoft
- **Purpose:** Full Python language support including IntelliSense,
  debugging, testing.
- **Platform Notes:**
  - Windows: Python path will be auto-detected if in `PATH`;
    compatible environments
    include system Python, venv, virtualenv, conda, conda-forge, Poetry,
    Pipenv, pyenv.
  - macOS/Linux: Same as Windows.
  - **Important:** For Ansible IDE support to work, a compatible Python environment
    must be installed on the system (not portable within VS Code).
- **Included Extensions:**
  - `ms-python.debugpy` (Python debugger)
  - `ms-python.vscode-pylance` (Language server)
  - `ms-python.vscode-python-envs` (Environment detection)
  - `ms-python.isort` (Import sorting, optional)

#### `redhat.ansible`

- **Publisher:** Red Hat
- **Purpose:** Ansible playbook and role editing with syntax highlighting, completion,
  and validation.
- **Platform Notes:**
  - Requires Ansible CLI to be installed locally for full validation.
  - Requires a compatible Python environment (see `ms-python.python`).
  - WSL and remote SSH workflows are supported.
- **Related Dependencies:** `redhat.vscode-yaml` (YAML support).

#### `redhat.vscode-yaml`

- **Publisher:** Red Hat
- **Purpose:** YAML syntax highlighting and validation.
- **Use Cases:** Ansible, cloud-init, Kubernetes, CI/CD configs, general YAML.
- **Related Dependencies:** None (standalone).

#### `timonwong.shellcheck`

- **Publisher:** Timon Wong
- **Purpose:** Shell script linting (bash, sh).
- **Platform Notes:**
  - Bundled `shellcheck` binaries are included for supported Windows, macOS,
    and Linux platforms.
  - A separate `shellcheck` CLI install is optional when you want to override
    the bundled binary or need support for an unsupported platform or
    architecture.
- **Related Dependencies:** None (standalone).

#### `nicolasvuillamy.vscode-groovy-lint`

- **Publisher:** Nicolas Vuillamy
- **Purpose:** Groovy and Jenkins DSL linting and formatting.
- **Platform Notes:**
  - The extension bundles the Groovy linting stack.
  - For the default setup path, no separate system Java install is required.
- **Related Dependencies:** None (standalone).

### Documentation & Quality Tools

#### `davidanson.vscode-markdownlint`

- **Publisher:** David Anson
- **Purpose:** Markdown linting for consistent document formatting.
- **Use Cases:** README files, documentation, commit message formatting.
- **Related Dependencies:** None (standalone).

#### `bierner.markdown-preview-github-styles`

- **Publisher:** Matt Bierner
- **Purpose:** Markdown preview with GitHub-flavored styling.
- **Use Cases:** Previewing README and documentation during editing.
- **Related Dependencies:** None (standalone).

#### `streetsidesoftware.code-spell-checker`

- **Publisher:** Street Side Software
- **Purpose:** Spell checking for code comments, strings, and documentation.
- **Usage Notes:** Project usage guidance and dictionary strategy are documented
  in `docs/vscode-cspell.md`.
- **Related Dependencies:** None (standalone).

### Remote & SSH Access

#### `ms-vscode-remote.remote-ssh`

- **Publisher:** Microsoft
- **Purpose:** SSH client integration for working on remote Linux hosts, lab systems, etc.
- **Platform Notes:**
  - Windows:
    - Can use Windows built-in SSH (Windows 10+) if configured.
    - Can use Git for Windows SSH client as an alternative.
    - Does NOT support Pageant or other third-party SSH agents in older versions.
  - macOS/Linux: Uses native SSH client.
  - **Important:** Direct access to lab hosts may require:
    - Fully qualified domain names (FQDN) for host discovery.
    - Local proxy settings for jump host access.
    - These configuration details are beyond the scope of this repository.
- **Related Dependencies:**
  - `ms-vscode-remote.remote-ssh-edit` (Remote file editing support)
  - `ms-vscode.remote-explorer` (Explorer UI for remote systems).

### Build Tools

#### `ms-vscode.makefile-tools`

- **Publisher:** Microsoft
- **Purpose:** Makefile support including syntax highlighting, task integration, and debugging.
- **Related Dependencies:** None (standalone).

#### `ms-vscode.powershell`

- **Publisher:** Microsoft
- **Purpose:** PowerShell script editing, IntelliSense, debugging, and execution.
- **Use Cases:** Windows build scripts, CI/CD pipeline scripts, setup automation.
- **Related Dependencies:** None (standalone).

---

## Dependencies (Automatically Installed)

These extensions are automatically installed as dependencies of the direct installs
above. **Do not install these separately.**

| Extension | Installed As Dependency Of | Purpose |
| --------- | ------------------------- | ------- |
| `ms-python.debugpy` | `ms-python.python` | Python runtime debugging support. |
| `ms-python.vscode-pylance` | `ms-python.python` | Pylance language server for advanced type checking. |
| `ms-python.vscode-python-envs` | `ms-python.python` | Automatic Python environment detection and management. |
| `ms-python.isort` | `ms-python.python` | Optional: Python import sorting. |
| `ms-vscode-remote.remote-ssh-edit` | `ms-vscode-remote.remote-ssh` | SSH file editing and remote path handling. |
| `ms-vscode.remote-explorer` | Remote SSH/WSL | Unified explorer UI for remote connections. |

---

## Platform-Specific Installation Requirements

This is mainly informational, some of these dependencies may be installed
by scripts run during setup of the IDE.

### Windows

1. **Git Installation**
   - Required by: `github.copilot-chat`
   - Download:
     [https://git-scm.com/download/win](https://git-scm.com/download/win)
   - Alternatively provides: SSH client (can be used instead of Windows SSH)

2. **Python**
   - Required by: `ms-python.python`, `redhat.ansible`
   - Options:
     - Windows Store: `python` app
     - System installer: python.org
     - Conda: conda-forge (recommended for Ansible users)
     - Package managers: `choco install python`, `scoop install python`
   - Verify: `python --version` in PowerShell

3. **shell** linting
   - Required by: `timonwong.shellcheck`
   - Separate install: not required on supported platforms because the VS Code
     extension bundles `shellcheck`
   - Optional standalone install: use winget, scoop, chocolatey, or a manual
     native install if you want a system `shellcheck` binary

4. **SSH Client**
   - Default: Windows 10+ native SSH (built-in)
   - Alternative: Git for Windows SSH client
   - For lab access: configure FQDN/proxy separately (out of scope)

### macOS

1. **Git**
   - Usually pre-installed; check: `git --version`
   - Or install via Homebrew: `brew install git`

2. **Python**
   - System Python: `python3` (usually available)
   - Managed: `brew install python@3.11` or use conda
   - Verify: `python3 --version`

3. **Ansible CLI** (for full validation)
   - Install: `brew install ansible`
   - Verify: `ansible --version`

4. **Shell linting**
   - Separate install: not required on supported platforms because the VS Code
     extension bundles `shellcheck`
   - Optional standalone install: `brew install shellcheck`

5. **SSH Client**
   - Built-in: OpenSSH (native)
   - Configure lab access separately if needed.

### Linux

1. **Git**
   - Do not assume it is pre-installed; check: `git --version`
   - Or: `sudo apt install git` (Debian/Ubuntu) or equivalent

2. **Python**
   - Often already present, especially on RPM-based systems; check:
     `python3 --version`
   - Or: Package manager install (e.g., `apt install python3`)

3. **Ansible CLI** (for full validation)
   - Install: `sudo apt install ansible` or equivalent
   - Verify: `ansible --version`

4. **Shell linting**
   - Separate install: not required on supported platforms because the VS Code
     extension bundles `shellcheck`
   - Optional standalone install: `apt install shellcheck` (Debian/Ubuntu)
   - Or equivalent on your distro

5. **SSH Client**
   - Built-in: OpenSSH client (usually pre-installed)
   - Configure lab access separately if needed.

---

## Not Included (Out of Scope)

The following kinds of extensions/tools are explicitly **not** part of
this baseline:

- **Docker/Podman:** Container tooling is deferred to a future phase.
  Direct local Docker development requires a paid Docker Desktop license
  on Windows; WSL-based
  workflows are better deferred until container strategy is decided.
- **Lab System Configuration:** FQDN discovery, jump host proxies, and other
  infrastructure-specific setup are handled outside this repository.
- **Third-Party Cloud SDKs:** AWS, Azure, Google Cloud extensions are
  not included by default but can be added on a per-project basis.

---

## Installation Quick Start

This is a manual fallback. In the normal path, `ide-workspace-setup` handles
the workspace files and recommended extension installs.

### Step 1: Install Base Extensions

```bash
code --install-extension github.copilot-chat
code --install-extension ms-python.python
code --install-extension redhat.ansible
code --install-extension redhat.vscode-yaml
code --install-extension timonwong.shellcheck
code --install-extension nicolasvuillamy.vscode-groovy-lint
code --install-extension davidanson.vscode-markdownlint
code --install-extension bierner.markdown-preview-github-styles
code --install-extension streetsidesoftware.code-spell-checker
code --install-extension ms-vscode-remote.remote-ssh
code --install-extension ms-vscode.makefile-tools
code --install-extension ms-vscode.powershell
```

### Step 2: Install Platform-Specific Tools

**Windows:**

Windows Python is obtained from the Microsoft Store.
Windows Git is obtained from its official location.

**macOS:**

```bash
brew install git python@3.11 ansible
```

**Linux:**

```bash
# Debian/Ubuntu example:
sudo apt install git python3 ansible
```

### Step 3: Verify Installations

```bash
git --version
python --version
ansible --version  # if Ansible CLI needed
```

`shellcheck --version` is only applicable if you installed a standalone system
`shellcheck` binary. The VS Code extension can work without it by using its
bundled binary.

---

## Future Enhancements

- [ ] Document Docker/Podman workflow once containerization
  strategy is finalized.
- [ ] Add cloud SDK recommendations if multi-cloud development is needed.
- [ ] Consider language-specific extensions (Go, Rust, etc.) based on
  project scope.
- [ ] Define Ansible-specific profiling recommendations once workflows
  are documented.
