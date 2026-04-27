#!/usr/bin/env python3
# Copyright 2026 Hewlett Packard Enterprise Development LP
import argparse
import importlib
import json
import os
import shutil
import subprocess
import sys


def ensure_yaml_module():
    """Return imported PyYAML module, installing it on demand if missing."""
    try:
        return importlib.import_module("yaml")
    except ImportError:
        if os.name != "nt":
            raise SystemExit(
                "Missing dependency: PyYAML. On non-Windows platforms, "
                "install the distro package first (for example: "
                "python3-yaml / PyYAML), then rerun setup."
            )
        print(
            "[ide-workspace-setup] PyYAML not found; attempting bootstrap install via pip"
        )
        install = subprocess.run(
            [
                sys.executable,
                "-m",
                "pip",
                "install",
                "--disable-pip-version-check",
                "pyyaml",
            ],
            capture_output=True,
            text=True,
        )
        if install.returncode != 0:
            details = "\n".join(
                part for part in (install.stdout.strip(), install.stderr.strip()) if part
            )
            raise SystemExit(
                "Missing dependency: PyYAML and bootstrap install failed. "
                "Install with 'python -m pip install pyyaml'.\n"
                + details
            )
        return importlib.import_module("yaml")


yaml = ensure_yaml_module()


def parse_yaml(path):
    result = {
        "vscode_settings": {},
        "vscode_extensions": [],
        "python_packages": [],
        "lint_profiles": [],
        "pre_commit_mode": "selected",
        "allow_uncertified_sources": False,
        "allowed_sources": [],
    }

    with open(path, "r", encoding="utf-8") as f:
        doc = yaml.safe_load(f) or {}

    if not isinstance(doc, dict):
        raise SystemExit("Invalid YAML: root document must be a mapping")

    ide = doc.get("ide", {})
    if ide and not isinstance(ide, dict):
        raise SystemExit("Invalid YAML: 'ide' must be a mapping")

    vscode = ide.get("vscode", {}) if isinstance(ide, dict) else {}
    if vscode and not isinstance(vscode, dict):
        raise SystemExit("Invalid YAML: 'ide.vscode' must be a mapping")

    settings = vscode.get("settings", {}) if isinstance(vscode, dict) else {}
    if settings and not isinstance(settings, dict):
        raise SystemExit("Invalid YAML: 'ide.vscode.settings' must be a mapping")
    result["vscode_settings"] = settings

    extensions = vscode.get("extensions", {}) if isinstance(vscode, dict) else {}
    if extensions and not isinstance(extensions, dict):
        raise SystemExit("Invalid YAML: 'ide.vscode.extensions' must be a mapping")
    recommendations = extensions.get("recommendations", []) if isinstance(extensions, dict) else []
    if recommendations and not isinstance(recommendations, list):
        raise SystemExit(
            "Invalid YAML: 'ide.vscode.extensions.recommendations' must be a list"
        )
    result["vscode_extensions"] = recommendations

    linting = doc.get("linting", {})
    if linting:
        if not isinstance(linting, dict):
            raise SystemExit("Invalid YAML: 'linting' must be a mapping")
        lint_profiles = linting.get("profiles", [])
        if lint_profiles and not isinstance(lint_profiles, list):
            raise SystemExit("Invalid YAML: 'linting.profiles' must be a list")
        result["lint_profiles"] = lint_profiles

    pre_commit = doc.get("preCommit", {})
    if pre_commit:
        if not isinstance(pre_commit, dict):
            raise SystemExit("Invalid YAML: 'preCommit' must be a mapping")
        result["pre_commit_mode"] = pre_commit.get("mode", "selected")

    pkg_sources = doc.get("packageSources", {})
    if pkg_sources:
        if not isinstance(pkg_sources, dict):
            raise SystemExit("Invalid YAML: 'packageSources' must be a mapping")
        allow_untrusted = pkg_sources.get("allowUncertifiedSources", False)
        if not isinstance(allow_untrusted, bool):
            raise SystemExit(
                "Invalid YAML: 'packageSources.allowUncertifiedSources' must be boolean"
            )
        allowed_sources = pkg_sources.get("allowedSources", [])
        if allowed_sources and not isinstance(allowed_sources, list):
            raise SystemExit(
                "Invalid YAML: 'packageSources.allowedSources' must be a list"
            )
        result["allow_uncertified_sources"] = allow_untrusted
        result["allowed_sources"] = allowed_sources

    setup = doc.get("setup", {})
    if setup:
        if not isinstance(setup, dict):
            raise SystemExit("Invalid YAML: 'setup' must be a mapping")
        setup_python = setup.get("python", {})
        if setup_python:
            if not isinstance(setup_python, dict):
                raise SystemExit("Invalid YAML: 'setup.python' must be a mapping")
            packages = setup_python.get("packages", [])
            if packages and not isinstance(packages, list):
                raise SystemExit("Invalid YAML: 'setup.python.packages' must be a list")
            for pkg in packages:
                if not isinstance(pkg, str):
                    raise SystemExit(
                        "Invalid YAML: each 'setup.python.packages' entry must be a string"
                    )
            result["python_packages"] = packages

    return result


def read_json(path):
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def deep_merge(base, overlay):
    """Merge overlay into base in-place.

    - Dicts are merged recursively.
    - Lists are union-merged so existing entries are never removed.
    - All other values in overlay replace the corresponding base value.
    """
    for key, value in overlay.items():
        if key in base and isinstance(base[key], dict) and isinstance(value, dict):
            deep_merge(base[key], value)
        elif key in base and isinstance(base[key], list) and isinstance(value, list):
            existing = base[key]
            for item in value:
                if item not in existing:
                    existing.append(item)
        else:
            base[key] = value


def normalize_rulers(rulers):
    """Collapse ruler entries by column number.

    VS Code accepts each ruler as either a plain integer (column only)
    or a dict with at minimum {"column": N} and an optional "color" key.
    When the same column appears as both a plain integer and a dict (or
    appears more than once), the dict form wins so that an explicitly
    assigned color is preserved.  Entries are returned sorted by column.
    """
    by_column = {}
    for entry in rulers:
        if isinstance(entry, int):
            col = entry
            if col not in by_column:
                by_column[col] = entry          # plain int as default
        elif isinstance(entry, dict) and "column" in entry:
            col = entry["column"]
            by_column[col] = entry              # dict always beats plain int
    return [by_column[col] for col in sorted(by_column)]


def canonicalize_shellcheck_settings(settings_obj):
    """Keep one canonical shellcheck key style.

    VS Code accepts both dotted and nested key styles. Preserve dotted keys
    as canonical output and collapse duplicate nested values created by merge.
    If both styles define a value for the same sub-key and they differ,
    preserve the dotted value and report the conflict.
    """
    nested_key = "shellcheck"

    if nested_key in settings_obj and isinstance(settings_obj[nested_key], dict):
        nested = settings_obj[nested_key]
        for sub_key, sub_value in nested.items():
            dotted_key = f"shellcheck.{sub_key}"
            if dotted_key not in settings_obj:
                settings_obj[dotted_key] = sub_value
            elif settings_obj[dotted_key] != sub_value:
                print(
                    "[ide-workspace-setup] WARNING: conflicting shellcheck "
                    f"settings for '{sub_key}'; preserving dotted key value"
                )
        settings_obj.pop(nested_key, None)


def find_code_cli():
    if os.name == "nt":
        code_cmd = shutil.which("code.cmd")
        if code_cmd:
            return code_cmd
    return shutil.which("code")


def ensure_python_packages(package_list, apply):
    """Ensure Python packages are installed in the current interpreter env."""
    seen = set()
    ordered = []
    for pkg in package_list:
        name = pkg.strip()
        if not name:
            continue
        lower = name.lower()
        if lower not in seen:
            seen.add(lower)
            ordered.append(name)

    for pkg in ordered:
        if os.name != "nt" and pkg.lower() == "pyyaml":
            print(
                "[ide-workspace-setup] non-Windows platform: skipping pip install "
                "for pyyaml; prefer distro package management"
            )
            continue
        if apply:
            result = subprocess.run(
                [
                    sys.executable,
                    "-m",
                    "pip",
                    "install",
                    "--disable-pip-version-check",
                    pkg,
                ],
                capture_output=True,
                text=True,
            )
            if result.returncode != 0:
                details = "\n".join(
                    part for part in (result.stdout.strip(), result.stderr.strip()) if part
                )
                print(
                    f"[ide-workspace-setup] WARNING: failed to install Python package {pkg}: "
                    + details
                )
            else:
                print(f"[ide-workspace-setup] ensured Python package: {pkg}")
        else:
            print(f"[ide-workspace-setup] would ensure Python package: {pkg}")


def install_extensions(ext_list, dry_run):
    code_cmd = find_code_cli()
    if not code_cmd:
        print(
            "[ide-workspace-setup] WARNING: 'code' not on PATH; "
            "extension install skipped"
        )
        print(
            "[ide-workspace-setup] rerun from a VS Code integrated terminal "
            "or add 'code' to PATH manually"
        )
        return

    # Get list of already-installed extensions
    installed_extensions = set()
    if not dry_run:
        result = subprocess.run(
            [code_cmd, "--list-extensions"],
            capture_output=True,
            text=True,
        )
        if result.returncode == 0:
            # Extract extension ID only (strip version info like @1.0.0)
            for line in result.stdout.splitlines():
                if line.strip():
                    # Split on @ to remove version info
                    ext_id = line.strip().split("@")[0].lower()
                    installed_extensions.add(ext_id)

    for ext in ext_list:
        if dry_run:
            print(f"[ide-workspace-setup] would ensure extension: {ext}")
        else:
            # Check if already installed (case-insensitive, ignoring version)
            ext_id = ext.lower().split("@")[0]
            if ext_id in installed_extensions:
                print(f"[ide-workspace-setup] already installed: {ext}")
            else:
                result = subprocess.run(
                    [code_cmd, "--install-extension", ext],
                    capture_output=True,
                    text=True,
                )
                combined_output = "\n".join(
                    part for part in (result.stdout.strip(), result.stderr.strip()) if part
                )
                if "already installed" in combined_output.lower():
                    print(f"[ide-workspace-setup] already installed: {ext}")
                elif "failed installing extensions" in combined_output.lower():
                    print(
                        f"[ide-workspace-setup] WARNING: install failed for {ext}: "
                        + combined_output
                    )
                elif result.returncode != 0:
                    print(
                        f"[ide-workspace-setup] WARNING: install failed for {ext}: "
                        + combined_output
                    )
                else:
                    print(f"[ide-workspace-setup] installed: {ext}")


def ensure_cspell_config(target_root, repo_root, apply):
    """Create cspell.config.yaml and project word list if they do not exist."""
    project_words = os.path.join(target_root, "vscode-project-words.txt")
    cspell_config = os.path.join(target_root, "cspell.config.yaml")

    # Check if cspell config already exists
    if os.path.exists(cspell_config):
        return

    if apply:
        # Create empty project-words.txt if it doesn't exist
        if not os.path.exists(project_words):
            with open(project_words, "w", encoding="utf-8") as f:
                f.write("# Project-specific words accepted by cspell\n")
                f.write("# Add one word per line\n")
            print(f"[ide-workspace-setup] created: {project_words}")

        # Create cspell.config.yaml
        cspell_content = """version: '0.2'
language: en
useGitignore: true
words: []
flagWords: []
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
"""
        with open(cspell_config, "w", encoding="utf-8") as f:
            f.write(cspell_content)
        print(f"[ide-workspace-setup] created: {cspell_config}")
    else:
        print(f"[ide-workspace-setup] would create: {cspell_config}")
        print(f"[ide-workspace-setup] would create: {project_words}")


def copy_linter_configs(target_root, repo_root, apply):
    """Copy linter config files from repo_root to target_root if missing."""
    # List of common linter/formatter config files to copy
    linter_files = [
        ".pylintrc",
        ".flake8",
        ".yamllint",
        "ansible.cfg",
        ".editorconfig",
        ".autopep8",
        "pyproject.toml",
        "setup.cfg",
    ]

    for filename in linter_files:
        src = os.path.join(repo_root, filename)
        dst = os.path.join(target_root, filename)

        # Only copy if source exists and destination does not
        if os.path.exists(src) and not os.path.exists(dst):
            if apply:
                shutil.copy2(src, dst)
                print(f"[ide-workspace-setup] copied: {dst}")
            else:
                print(f"[ide-workspace-setup] would copy: {filename}")


def main(argv):
    parser = argparse.ArgumentParser()
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--config", default="")
    args = parser.parse_args(argv)

    repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), os.pardir))
    target_root = os.getcwd()
    default_yaml = os.path.join(target_root, "local_ide_settings.yml")
    reference_yaml = os.path.join(
        repo_root, "ide", "reference", "recommended_settings.yml"
    )

    config_path = args.config or (
        default_yaml if os.path.exists(default_yaml) else reference_yaml
    )
    if not os.path.exists(config_path):
        raise SystemExit(f"Config file not found: {config_path}")

    cfg = parse_yaml(config_path)
    if cfg["pre_commit_mode"] not in ("selected", "none", "all"):
        raise SystemExit("Invalid pre_commit_mode: expected selected|none|all")

    baseline_cfg = parse_yaml(reference_yaml)
    baseline_settings = baseline_cfg["vscode_settings"]
    baseline_extensions = baseline_cfg["vscode_extensions"]

    out_settings = os.path.join(target_root, ".vscode", "settings.json")
    out_ext = os.path.join(target_root, ".vscode", "extensions.json")

    # Start from any existing workspace settings so nothing is lost.
    # Merge order (each step can add/override the previous):
    #   existing .vscode/settings.json -> repo baseline -> local YAML
    existing_settings = {}
    if os.path.exists(out_settings):
        try:
            existing_settings = read_json(out_settings)
        except Exception:
            print(
                f"[ide-workspace-setup] WARNING: could not read existing "
                f"{out_settings}; starting from baseline only"
            )

    merged_settings = {}
    deep_merge(merged_settings, existing_settings)
    deep_merge(merged_settings, baseline_settings)
    deep_merge(merged_settings, cfg["vscode_settings"])

    # Rulers need column-aware deduplication; plain ints and dicts with the
    # same column number must be collapsed to a single entry (dict wins).
    rulers = merged_settings.get("editor", {}).get("rulers")
    if isinstance(rulers, list):
        merged_settings["editor"]["rulers"] = normalize_rulers(rulers)

    canonicalize_shellcheck_settings(merged_settings)

    # Build extension list: existing + baseline + selected YAML config,
    # deduped and order-preserving.
    existing_recommendations = []
    if os.path.exists(out_ext):
        try:
            existing_recommendations = read_json(
                out_ext).get("recommendations", [])
        except Exception:
            pass

    ext_ordered = list(existing_recommendations)
    for ext in baseline_extensions:
        if ext not in ext_ordered:
            ext_ordered.append(ext)
    for ext in cfg["vscode_extensions"]:
        if ext not in ext_ordered:
            ext_ordered.append(ext)

    print(f"[ide-workspace-setup] config: {config_path}")
    print(f"[ide-workspace-setup] target workspace: {target_root}")
    print(
        "[ide-workspace-setup] extensions (existing + baseline + config): "
        + str(len(ext_ordered))
    )
    print(
        "[ide-workspace-setup] lint profiles: "
        + (", ".join(cfg["lint_profiles"]) if cfg["lint_profiles"] else "(none)")
    )
    print(f"[ide-workspace-setup] pre-commit mode: {cfg['pre_commit_mode']}")

    ensure_python_packages(cfg["python_packages"], apply=args.apply)

    if args.apply:
        os.makedirs(os.path.join(target_root, ".vscode"), exist_ok=True)
        with open(out_settings, "w", encoding="utf-8") as f:
            json.dump(merged_settings, f, indent=2)
            f.write("\n")
        with open(out_ext, "w", encoding="utf-8") as f:
            json.dump({"recommendations": ext_ordered}, f, indent=2)
            f.write("\n")
        print(f"[ide-workspace-setup] applied settings: {out_settings}")
        print(f"[ide-workspace-setup] applied extensions: {out_ext}")
        install_extensions(ext_ordered, dry_run=False)
        ensure_cspell_config(target_root, repo_root, apply=True)
        copy_linter_configs(target_root, repo_root, apply=True)
    else:
        print("[ide-workspace-setup] DRY RUN (no files written)")
        print(f"[ide-workspace-setup] would write: {out_settings}")
        print(f"[ide-workspace-setup] would write: {out_ext}")
        install_extensions(ext_ordered, dry_run=True)
        ensure_cspell_config(target_root, repo_root, apply=False)
        copy_linter_configs(target_root, repo_root, apply=False)

    print(
        "[ide-workspace-setup] rerun after editing "
        "./local_ide_settings.yml"
    )


if __name__ == "__main__":
    main(sys.argv[1:])
