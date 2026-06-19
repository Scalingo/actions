# ShellCheck Test Layout

This directory contains the end-to-end test for `shellcheck/scripts/run-shellcheck.sh`.

## Files

- `execution.sh`: runs the test scenario and checks the arguments passed to ShellCheck.
- `bin/shellcheck`: a fake ShellCheck binary that records its arguments instead of executing the real tool.
- `fixtures/scalingo-one/match.sh`: fixture used to verify that glob expansion matches the first path.
- `fixtures/scalingo-two/match.sh`: fixture used to verify that glob expansion and duplicate entries are preserved.

## What The Test Verifies

The test exercises the `FILES` branch in `run-shellcheck.sh` and checks that:

- newline-separated entries are split into separate paths
- shell glob patterns are expanded
- duplicate paths are passed through unchanged

The recorded arguments are written to a temporary file created by `execution.sh`.
