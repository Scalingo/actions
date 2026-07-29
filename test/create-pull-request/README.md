# create-pull-request action E2E test

This directory contains an end-to-end test for the vendored
[`create-pull-request`](/create-pull-request) action.

Unlike the other tests in this repository, this one exercises the action for
real: it spins up a disposable GitHub repository, adds a workflow that uses
`Scalingo/actions/create-pull-request@<ref>`, triggers it, and asserts on the
resulting pull request via the GitHub API. This is required because the
action's behaviour (creating/updating a PR, computing outputs, diffing
against `GITHUB_WORKSPACE`, etc.) can only be observed by actually running it
inside GitHub Actions.

## Requirements

- [`gh`](https://cli.github.com/), authenticated with at least the `repo` and
  `delete_repo` scopes (`gh auth status`; add a missing scope with
  `gh auth refresh -h github.com -s delete_repo`). `delete_repo` is only
  needed for automatic cleanup of the disposable repository.
- [`bats-core`](https://github.com/bats-core/bats-core) (`bats --version`).
- `jq` and `git`.

## Usage

```bash
# Test the action as currently committed on main
./test/create-pull-request/run-e2e-test.sh

# Test a specific branch of Scalingo/actions
./test/create-pull-request/run-e2e-test.sh --ref feat/SITM-2436/fork-create-pull-request

# Test the exact commit backing a pull request on Scalingo/actions
./test/create-pull-request/run-e2e-test.sh --pr 80

# Keep the disposable repository around after the run (debugging)
./test/create-pull-request/run-e2e-test.sh --pr 80 --keep

# Also write a JUnit report
./test/create-pull-request/run-e2e-test.sh --pr 80 --report-dir /tmp/cpr-report
```

Run `./test/create-pull-request/run-e2e-test.sh --help` for the full list of
options.

## What it does

1. Resolves the action ref to test (`--ref`, or the head commit of a
   Scalingo/actions pull request via `--pr`).
2. Creates a disposable, private GitHub repository under the given (or
   current) `gh` account with a workflow at
   `.github/workflows/e2e-create-pull-request.yml` that:
   - makes a change to a file, and
   - runs `Scalingo/actions/create-pull-request@<ref>` to open a PR for it.
3. Triggers the workflow once, waits for it to complete, and validates (via
   `test/create-pull-request/create-pull-request.bats`, a Bats test suite)
   that:
   - the run succeeded,
   - exactly one pull request was opened, with the expected title, branch,
     and body,
   - the action's `pull-request-number` output matches the real PR.
4. Triggers the workflow a second time with a different change, and
   validates that the **same** pull request is updated (not a second one
   created), that the `pull-request-operation` output reports `updated`, and
   that the PR diff contains the latest change.
5. Deletes the disposable repository, unless `--keep` was passed.
6. Prints a pass/fail report to the console (and, with `--report-dir`, a
   JUnit XML report).
