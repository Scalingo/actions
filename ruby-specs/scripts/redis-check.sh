#!/usr/bin/env bash
#
# Check the WITH_REDIS value to determine whether Redis needs to be started or not.
# WITH_REDIS is set in the environment by the calling GitHub Action.
# This script writes on stdout what needs to be redirected to GITHUB_OUTPUT to set the variable should_start.
#

if [[ $# -ne 0 ]] || [[ -z "$WITH_REDIS" ]]; then
  echo "Usage: $0" >&2
  echo "WITH_REDIS environment variable must be set with one of the following value: true | false | auto" >&2
  exit 1
fi

if [[ "$WITH_REDIS" != "true" ]] && [[ "$WITH_REDIS" != "false" ]] && [[ "$WITH_REDIS" != "auto" ]]; then
  echo "invalid 'WITH_REDIS' value ($WITH_REDIS)" >&2
  exit 1
fi

if [[ "$WITH_REDIS" == "true" ]]; then
  echo "should_start=true"
  exit 0
fi

if [[ "$WITH_REDIS" == "false" ]]; then
  echo "should_start=false"
  exit 0
fi

# Check if `redis` gem is used in the Gemfile.lock
if grep --quiet "^\s*redis\s*(" Gemfile.lock 2>/dev/null; then
  echo "should_start=true"
  exit 0
fi

echo "should_start=false"
