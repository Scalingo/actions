#!/usr/bin/env bash

set -euo pipefail

tmp_dir=$(mktemp -d)
readonly tmp_dir
readonly output_file="$tmp_dir/ansible-lint-argv.txt"
readonly marker_file="$tmp_dir/command-substitution-was-executed"
readonly repo_root="$PWD"
readonly bin_dir="$repo_root/test/ansible-linter/bin"

cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

assert_argv() {
  local -a expected_args=("$@")

  if ! diff -u <(printf '%s\n' "${expected_args[@]}") "$output_file"; then
    echo "Ansible Lint received the wrong arguments." >&2
    exit 1
  fi
}

export PATH="$bin_dir:$PATH"
export GITHUB_WORKSPACE="$repo_root"
export ANSIBLE_LINT_OUTPUT_FILE="$output_file"
export WORKING_DIRECTORY="$repo_root/test/ansible-linter/fixture"
export ARGS='--exclude ignored.yml'
# The literal command substitution is test data and must not be evaluated.
# shellcheck disable=SC2016
malicious_file=$(printf '$(touch "%s")' "$marker_file")
readonly malicious_file
export FILES=$'test/ansible-linter/fixture/*.yml\n'\
$'test/ansible-linter/fixture/playbook.yml\n'"$malicious_file"

bash "$repo_root/ansible-linter/scripts/run-ansible-lint.sh"

if [[ -e "$marker_file" ]]; then
  echo "A filename was evaluated as shell code." >&2
  exit 1
fi

assert_argv \
  "--exclude" \
  "ignored.yml" \
  "--" \
  "$repo_root/test/ansible-linter/fixture/playbook.yml" \
  "$repo_root/test/ansible-linter/fixture/playbook.yml" \
  "$repo_root/\$(touch" \
  "$repo_root/\"$marker_file\")"

: >"$output_file"
export FILES=$'\n \n\t'

bash "$repo_root/ansible-linter/scripts/run-ansible-lint.sh"

assert_argv \
  "--exclude" \
  "ignored.yml"
