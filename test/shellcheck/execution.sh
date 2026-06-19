#!/usr/bin/env bash

set -euo pipefail

readonly tmp_dir="$(mktemp -d)"
readonly output_file="$tmp_dir/shellcheck-argv.txt"
readonly repo_root="$PWD"
readonly workspace="$repo_root"
readonly bin_dir="$repo_root/test/shellcheck/bin"

cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

run_action() {
  cd "$workspace"
  /bin/sh "$repo_root/shellcheck/scripts/run-shellcheck.sh"
}

assert_shellcheck_argv() {
  local -a expected_args=(
    "--severity=warning"
    "--shell=bash"
    "--"
    "test/shellcheck/fixtures/scalingo-one/match.sh"
    "test/shellcheck/fixtures/scalingo-two/match.sh"
    "test/shellcheck/fixtures/scalingo-two/match.sh"
  )
  local -a actual_args=()

  mapfile -t actual_args <"$output_file"

  if ! diff -u <(printf '%s\n' "${expected_args[@]}") <(printf '%s\n' "${actual_args[@]}"); then
    echo "ShellCheck received the wrong arguments." >&2
    echo "This test protects the FILES handling in run-shellcheck.sh:" >&2
    echo "- newline-separated entries are split into individual paths" >&2
    echo "- glob patterns are expanded by the shell" >&2
    echo "- duplicate paths are preserved" >&2
    exit 1
  fi
}

export PATH="$bin_dir:$PATH"
export GITHUB_WORKSPACE="$workspace"
export GITHUB_ACTION_PATH="$repo_root/shellcheck"
export SHELLCHECK_OUTPUT_FILE="$output_file"
export FILES=$'test/shellcheck/fixtures/scalingo-*/match.sh\n'\
$'test/shellcheck/fixtures/scalingo-two/match.sh'
export SEVERITY=warning

run_action
assert_shellcheck_argv
