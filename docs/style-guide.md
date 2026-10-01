<!-- Copyright 2026 Hewlett Packard Enterprise Development LP -->

# Project Style Guide

For Ansible-specific guidelines, see the [Ansible Style Guide](ansible-style-guide.md).

## Copyright

The following file types must include a copyright notice:

- Bash scripts (`.sh`) — place on the second line, after the shebang
- Markdown documentation files (`.md`) — place on the first line

Use the comment style appropriate for the file type:

```bash
# Copyright 2026 Hewlett Packard Enterprise Development LP
```

```html
<!-- Copyright 2026 Hewlett Packard Enterprise Development LP -->
```

Update the year to match the year the file was created.

Bash scripts and markdown files must also include an SPDX license identifier
line immediately after the copyright notice:

```bash
# SPDX-License-Identifier: BSD-2-Clause-Patent
```

```html
<!-- SPDX-License-Identifier: BSD-2-Clause-Patent -->
```

## Bash Scripts

### Header

Every bash script must start with:

```bash
#!/bin/bash
#
# Copyright 2026 Hewlett Packard Enterprise Development LP
#
# SPDX-License-Identifier: BSD-2-Clause-Patent
```

### Formatting

- Use **2-space indentation**.
- No trailing whitespace.

### Safety

- Add `set -euo pipefail` near the top of every script to exit on errors,
  unset variables, and pipe failures.
- Send error messages to stderr: `echo "error message" >&2`

### Variables

- Quote all variable expansions: `"$var"` not `$var`.
- Use `UPPER_CASE` for constants and environment variables, `lower_case` for
  local variables.
- Use `readonly` for variables that must not be reassigned.

### Functions

- Use `snake_case` for function names.
- Declare variables inside functions with `local`.

### Conditionals & Substitutions

- Prefer `[[ ]]` over `[ ]` for conditionals.
- Use `$(...)` for command substitution instead of backticks.
