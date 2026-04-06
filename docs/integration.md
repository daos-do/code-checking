# Integration

Consumer repositories should add this repository as a top-level submodule:

```bash
git submodule add https://github.com/daos-do/code-checking code_checking
git submodule update --init --recursive
```

Consumer repositories keep local wrappers and workflow files and call shared
scripts from `code_checking/`.
