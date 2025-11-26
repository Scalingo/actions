#!/usr/bin/env bash
#
# Check if RuboCop should be executed
# WITH_RUBOCOP is set in the environment by the calling GitHub Action.
# This script writes to stdout what needs to be redirected to GITHUB_OUTPUT to set the variable should_run.
#

if [[ $# -ne 0 ]] || [[ -z "$WITH_RUBOCOP" ]]; then
  echo "Usage: $0" >&2
  echo "WITH_RUBOCOP environment variable must be set with one of the following value: true | false | auto" >&2
  exit 1
fi

if [[ "$WITH_RUBOCOP" != "true" ]] && [[ "$WITH_RUBOCOP" != "false" ]] && [[ "$WITH_RUBOCOP" != "auto" ]]; then
  echo "invalid 'WITH_RUBOCOP' value ($WITH_RUBOCOP)" >&2
  exit 1
fi

if [[ "$WITH_RUBOCOP" == "true" ]]; then
  echo "should_run=true"
  exit 0
fi

if [[ "$WITH_RUBOCOP" == "false" ]]; then
  echo "should_run=false"
  exit 0
fi

# Check if rubocop is available in the bundle
if bundle exec rubocop --version &>/dev/null; then
  echo "should_run=true"
  exit 0
fi

echo "should_run=false"
