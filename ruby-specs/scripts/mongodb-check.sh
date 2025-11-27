#!/usr/bin/env bash
#
# Check the WITH_MONGODB value to determine whether MongoDB needs to be started or not.
# WITH_MONGODB is set in the environment by the calling GitHub Action.
# This script writes on stdout what needs to be redirected to GITHUB_OUTPUT to set the variable should_start.
#

if [[ $# -ne 0 ]] || [[ -z "$WITH_MONGODB" ]]; then
  echo "Usage: $0" >&2
  echo "WITH_MONGODB environment variable must be set with one of the following value: true | false | auto" >&2
  exit 1
fi

if [[ "$WITH_MONGODB" != "true" ]] && [[ "$WITH_MONGODB" != "false" ]] && [[ "$WITH_MONGODB" != "auto" ]]; then
  echo "invalid 'WITH_MONGODB' value ($WITH_MONGODB)" >&2
  exit 1
fi

if [[ "$WITH_MONGODB" == "true" ]]; then
  echo "should_start=true"
  exit 0
fi

if [[ "$WITH_MONGODB" == "false" ]]; then
  echo "should_start=false"
  exit 0
fi

# Check if `mongoid` gem is used in the Gemfile
if grep --quiet "mongoid" Gemfile 2>/dev/null; then
  echo "should_start=true"
  exit 0
fi

echo "should_start=false"
