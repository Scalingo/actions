# ShellCheck

A composite GitHub Action that runs ShellCheck on a repository.

The action checks out the repository and runs ShellCheck in Docker. By default,
it scans all `.sh` files recursively, excluding the `.git` directory. All files
are checked as Bash scripts, regardless of their shebang.

The workflow step fails when ShellCheck reports findings at the selected
severity or higher, or encounters an error.


## Available Inputs

- `version` (opt):\
  Version of ShellCheck to use.\
  Must match a tag of the [`koalaman/shellcheck-alpine`](https://hub.docker.com/r/koalaman/shellcheck/tags)
  Docker image.\
  Defaults to `v0.11.0`.

- `severity` (opt):\
  Minimum severity of findings to report.\
  Valid values, from most to least severe, are `error`, `warning`, `info`, and
  `style`.\
  Defaults to `style`.

- `files` (opt):\
  Paths or glob expressions to scan, relative to the repository root.\
  Separate entries with newlines. Spaces in filenames are not supported with
  this input.\
  Defaults to all `.sh` files in the repository, excluding the `.git`
  directory.

- `enable_all_checks` (opt):\
  Set to `"true"` to enable all optional ShellCheck checks, equivalent to
  `--enable=all`.\
  Defaults to `"false"`.


## Instructions

- Use a Linux runner with Bash and Docker available, such as `ubuntu-latest`.

- Declare `contents: read` permission in the calling workflow or job so the
  action can check out the repository.

- The action performs checkout itself; a separate checkout step is unnecessary.

- Omit `files` to scan all `.sh` files, or specify paths and glob expressions
  to select files explicitly, including scripts without a `.sh` extension.


## Example

```yaml
name: ShellCheck

on: [push, pull_request]

jobs:
  shellcheck:
    name: ShellCheck
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - name: Check shell scripts
        uses: Scalingo/actions/shellcheck@main
        with:
          version: v0.11.0
          severity: style
          enable_all_checks: true
          files: |
            first_file.sh
            second/*.sh
            third.sh
```
