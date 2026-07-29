#!/usr/bin/env bash
#
# End-to-end test for the vendored `create-pull-request` action.
#
# This script:
#   1. Resolves the action ref to test (a branch, tag, SHA, or a Scalingo/actions
#      pull request number).
#   2. Delegates to a Bats test suite (create-pull-request.bats) which creates a
#      disposable GitHub repository, wires up a workflow that uses the action at
#      the resolved ref, triggers it, and validates the resulting pull request.
#   3. Prints a human-readable report (and, optionally, a JUnit report file).
#
# Requirements: gh (authenticated, with `repo` scope), bats, jq, git.
#
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly script_dir
readonly bats_file="$script_dir/create-pull-request.bats"

usage() {
  cat <<'EOF'
Usage: run-e2e-test.sh [OPTIONS]

Test the vendored create-pull-request action end to end by creating a
disposable GitHub repository, running a workflow that uses the action, and
validating the resulting pull request.

Options:
  -r, --ref <ref>        Branch, tag, or commit SHA of Scalingo/actions to test.
                          (default: main)
  -p, --pr <number>      Test the head commit of this Scalingo/actions pull
                          request instead of --ref.
  -o, --owner <owner>    GitHub owner (user or org) under which the disposable
                          test repository is created. (default: current gh user)
  -k, --keep             Do not delete the disposable repository after the run
                          (useful to inspect it while debugging a failure).
  -O, --report-dir <dir> Directory to write a JUnit report to, in addition to
                          the console report. (default: no report file)
  -h, --help             Show this help message.

Examples:
  ./run-e2e-test.sh --ref main
  ./run-e2e-test.sh --ref feat/SITM-2436/fork-create-pull-request
  ./run-e2e-test.sh --pr 80
EOF
}

ref="main"
pr_number=""
owner=""
keep="0"
report_dir=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -r|--ref)
      ref="$2"
      shift 2
      ;;
    -p|--pr)
      pr_number="$2"
      shift 2
      ;;
    -o|--owner)
      owner="$2"
      shift 2
      ;;
    -k|--keep)
      keep="1"
      shift
      ;;
    -O|--report-dir)
      report_dir="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

for bin in gh bats jq git; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "error: '$bin' is required but was not found in PATH" >&2
    exit 1
  fi
done

if ! gh auth status >/dev/null 2>&1; then
  echo "error: gh is not authenticated. Run 'gh auth login' first." >&2
  exit 1
fi

# The disposable test repository is deleted automatically in teardown, unless
# --keep was passed. Deleting a repo requires the 'delete_repo' OAuth scope,
# which isn't granted by default. Proactively check for it and offer to
# request it now, so the run doesn't end with an orphaned repo.
if [[ "$keep" != "1" ]] && ! gh auth status 2>&1 | grep -q "'delete_repo'"; then
  echo "warning: gh is missing the 'delete_repo' scope, needed to automatically delete the disposable test repository afterwards." >&2
  if [[ -t 0 && -t 1 ]]; then
    read -r -p "Authorize it now via 'gh auth refresh -h github.com -s delete_repo'? [y/N] " reply
    if [[ "$reply" =~ ^[Yy]$ ]]; then
      gh auth refresh -h github.com -s delete_repo
    fi
  fi
  if ! gh auth status 2>&1 | grep -q "'delete_repo'"; then
    echo "warning: proceeding without the 'delete_repo' scope. If the disposable repository can't be deleted automatically, its URL and a manual cleanup command will be printed at the end of this run." >&2
  fi
fi

if [[ -n "$pr_number" ]]; then
  echo "Resolving head commit of Scalingo/actions PR #$pr_number..."
  resolved_sha="$(gh pr view "$pr_number" --repo Scalingo/actions --json headRefOid -q .headRefOid)"
  if [[ -z "$resolved_sha" ]]; then
    echo "error: could not resolve PR #$pr_number on Scalingo/actions" >&2
    exit 1
  fi
  ref="$resolved_sha"
  echo "Resolved PR #$pr_number to commit $ref"
fi

if [[ -z "$owner" ]]; then
  owner="$(gh api user -q .login)"
fi

echo
echo "=== create-pull-request action E2E test ==="
echo "Action ref under test : Scalingo/actions/create-pull-request@$ref"
echo "Scratch repo owner     : $owner"
echo "Keep scratch repo      : $keep"
echo "============================================"
echo

export CPR_REF="$ref"
export CPR_OWNER="$owner"
export CPR_KEEP="$keep"

bats_args=(--print-output-on-failure --timing)
if [[ -n "$report_dir" ]]; then
  mkdir -p "$report_dir"
  bats_args+=(--report-formatter junit --output "$report_dir")
fi

set +e
bats "${bats_args[@]}" "$bats_file"
bats_status=$?
set -e

echo
echo "=== Report ==="
if [[ -n "$report_dir" ]]; then
  echo "JUnit report written to: $report_dir"
fi
if [[ "$bats_status" -eq 0 ]]; then
  echo "RESULT: PASS - the create-pull-request action behaved as expected for ref '$ref'."
else
  echo "RESULT: FAIL - the create-pull-request action did NOT behave as expected for ref '$ref'."
fi
echo "=============="

exit "$bats_status"
