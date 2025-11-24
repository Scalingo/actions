#!/usr/bin/env bash
#
# Check the WITH_PACT value to determine whether Pact verification needs to be run or not.
# WITH_PACT is set in the environment by the calling GitHub Action.
# This script writes on stdout what needs to be redirected to GITHUB_OUTPUT to set the variable should_run.
#

if [[ $# -ne 0 ]] || [[ -z "$WITH_PACT" ]]; then
  echo "Usage: $0" >&2
  echo "WITH_PACT environment variable must be set with one of the following value: true | false | auto" >&2
  exit 1
fi

if [[ "$WITH_PACT" != "true" ]] && [[ "$WITH_PACT" != "false" ]] && [[ "$WITH_PACT" != "auto" ]]; then
  echo "invalid 'WITH_PACT' value ($WITH_PACT)" >&2
  exit 1
fi

if [[ "$WITH_PACT" == "true" ]]; then
  echo "should_run=true"
  exit 0
fi

if [[ "$WITH_PACT" == "false" ]]; then
  echo "should_run=false"
  exit 0
fi

# Check if `pact:verify` task exists
if bundle exec rake --tasks | grep --quiet "pact:verify"; then
  echo "should_run=true"
  exit 0
fi

echo "should_run=false"
