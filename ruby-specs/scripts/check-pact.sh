#!/usr/bin/env bash
#
# Check if Pact verification should be executed
# WITH_PACT is set in the environment by the calling GitHub Action.
# This script writes to stdout what needs to be redirected to GITHUB_OUTPUT to set the variable should_run.
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"${SCRIPT_DIR}/check-tool.sh" "WITH_PACT" "bundle exec rake --tasks | grep --quiet 'pact:verify'"
