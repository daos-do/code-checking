# VS Code Code Spell Checker Usage

This document covers use of the VS Code extension
`streetsidesoftware.code-spell-checker`.

It is intentionally separate from `codespell`, which is the spell checker used
by commit hooks and GitHub Actions.

The VS Code spell checker can use a repository-stored configuration file and a
repository-stored custom dictionary file that are separate from the dictionary
or ignore-word files used by `codespell` in commit hooks and CI.

Recommended pattern:

- Use a repo `cspell` config file for IDE spell checking.
- Use a separate repo text file for IDE-specific accepted words.
- Keep `codespell` ignore words and config separate for hooks and CI.
- Do not rely on user-global settings or `.vscode/settings.json` for project
  training.

## Important Distinction

These are different tools:

- VS Code extension: `streetsidesoftware.code-spell-checker`
- Underlying config format for that extension: `cspell`
- Commit hook / CI tool: `codespell`

They do not use the same dictionary format and do not read the same config files
by default.

That means a repo `cspell.json` or `cspell.config.yaml` file can be committed
for IDE use without changing `codespell` behavior in hooks or GitHub Actions.

## Why a Separate IDE Dictionary Makes Sense

The Code Spell Checker extension is designed to catch unknown words in general
text and code comments. It often needs project-specific training for:

- product names
- repository names
- acronyms
- internal abbreviations
- domain-specific terms

`codespell` behaves differently. It uses curated typo dictionaries and is better
at catching common misspellings with fewer project-training changes.

Because of that difference, it is reasonable to keep:

- a `codespell` allowlist for hook and CI false positives
- a separate `cspell` project dictionary for IDE comfort

## Recommended Repository Layout

Suggested files:

- `cspell.config.yaml`
- `vscode-project-words.txt`

Example purpose of each file:

- `cspell.config.yaml`: project-level config for the VS Code extension
- `vscode-project-words.txt`: accepted words for IDE spell checking

## Recommended Configuration

A root `cspell.config.yaml` file is the cleanest option because the VS Code
extension can discover it automatically in the repository.

Example:

```yaml
version: '0.2'
language: en
useGitignore: true
words: []
dictionaryDefinitions:
  - name: project-words
    path: ./vscode-project-words.txt
    addWords: true
    scope: workspace

dictionaries:
  - project-words

ignorePaths:
  - .git/**
  - .venv/**
  - node_modules/**
```

Example dictionary file:

```text
ansible-lab
codespell
groovylint
shellcheck
```

## How This Helps

With that pattern:

- the VS Code extension gets a project dictionary from the repository
- the dictionary file is separate from `codespell` hook configuration
- user-global spell checker state is not required
- project-specific training can be reviewed like normal source changes

## How to Add Words

Preferred order:

1. If the word is a real project term used broadly, add it to the repo
  `vscode-project-words.txt` file.
2. If the word is specific to one file, use an inline `cSpell:ignore` or
   `cSpell:words` comment.
3. If the word is personal or not appropriate for the repository, keep it in the
   user's own global dictionary instead of committing it.

In VS Code, right-click on a misspelled word and choose one of these:

- Add to Workspace Dictionary: writes the word to `vscode-project-words.txt`
  based on `cspell.config.yaml` dictionaryDefinitions.
- Add to Workspace Settings: writes the word into `.vscode/settings.json`
  (`cSpell.words`) for this workspace.
- Add to User Settings: writes the word into your personal VS Code user settings.

Recommended team workflow:

1. Use Add to Workspace Dictionary for stable, project-wide terms.
2. Review and commit updates in `vscode-project-words.txt`.
3. Use Add to Workspace Settings only for temporary local exceptions.
4. Use Add to User Settings only for personal preferences.

Manual edit workflow:

1. Open `vscode-project-words.txt` in the repository root.
2. Add one accepted word per line.
3. Save the file; VS Code cspell diagnostics update automatically.
4. Commit the change when the term is broadly applicable to the project.

Examples:

JavaScript / TypeScript / many code files:

```text
// cSpell:ignore myspecialtoken
// cSpell:words repoSpecificTerm
```

Markdown:

```html
<!-- cSpell:ignore myspecialtoken -->
```

## What Not to Do

Avoid these patterns for project training:

- storing project spell-check training only in VS Code user settings
- storing project spell-check training only in `.vscode/settings.json`
- mixing `cspell` project words into `codespell` ignore-word files

Those approaches either make the setup non-portable or blur the distinction
between the IDE checker and the hook/CI checker.

## Interaction With `codespell`

`codespell` uses its own configuration and allowlist mechanisms, such as:

- `.codespellrc`
- `setup.cfg`
- `pyproject.toml`
- `codespell -I <file>` ignore-word files

A `cspell.config.yaml` or `cspell.json` file does not replace those and does not
change `codespell` behavior unless you explicitly wire the two together.

That separation is useful here.

## Recommended Policy For This Repository

Recommended baseline:

- Commit a repo-level `cspell` config for IDE use.
- Commit a repo-level `vscode-project-words.txt` file for IDE-only accepted terms.
- Keep `codespell` hook and CI configuration separate.
- Only add stable, broadly used terms to the repo IDE dictionary.
- Keep user-specific or temporary words out of the repository.

## Scope Note

This document only covers repository-managed spell-check behavior for the VS Code
extension.

It does not attempt to standardize:

- a user's personal global dictionary
- local site policy for extension installation
- local AI policy or compliance requirements
- editor settings unrelated to spell checking

## Current Repository State

This repository currently uses:

1. `cspell.config.yaml`
2. `vscode-project-words.txt`
3. separate `codespell` configuration for hooks and CI
