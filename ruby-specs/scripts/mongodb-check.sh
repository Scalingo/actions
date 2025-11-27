#!/usr/bin/env bash
#
# Check the WITH_MONGODB value to determine whether MongoDB needs to be started or not.
# WITH_MONGODB is set in the environment by the calling GitHub Action.
# This script writes on stdout what needs to be redirected to GITHUB_OUTPUT to set the variable should_start.
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"${SCRIPT_DIR}/check-tool.sh" "WITH_MONGODB" "grep --quiet 'mongoid' Gemfile 2>/dev/null"
