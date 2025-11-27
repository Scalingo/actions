#!/usr/bin/env bash
#
# Check the WITH_REDIS value to determine whether Redis needs to be started or not.
# WITH_REDIS is set in the environment by the calling GitHub Action.
# This script writes on stdout what needs to be redirected to GITHUB_OUTPUT to set the variable should_start.
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"${SCRIPT_DIR}/check-tool.sh" "WITH_REDIS" "grep --quiet 'redis' Gemfile 2>/dev/null"
