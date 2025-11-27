#!/usr/bin/env bash
#
# Check if RuboCop should be executed
# WITH_RUBOCOP is set in the environment by the calling GitHub Action.
# This script writes to stdout what needs to be redirected to GITHUB_OUTPUT to set the variable should_run.
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"${SCRIPT_DIR}/check-tool.sh" "WITH_RUBOCOP" "bundle exec rubocop --version"
