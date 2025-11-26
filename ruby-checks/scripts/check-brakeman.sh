#!/usr/bin/env bash
#
# Check if Brakeman should be executed
# WITH_BRAKEMAN is set in the environment by the calling GitHub Action.
# This script writes to stdout what needs to be redirected to GITHUB_OUTPUT to set the variable should_run.
#

if [[ $# -ne 0 ]] || [[ -z "$WITH_BRAKEMAN" ]]; then
  echo "Usage: $0" >&2
  echo "WITH_BRAKEMAN environment variable must be set with one of the following value: true | false | auto" >&2
  exit 1
fi

if [[ "$WITH_BRAKEMAN" != "true" ]] && [[ "$WITH_BRAKEMAN" != "false" ]] && [[ "$WITH_BRAKEMAN" != "auto" ]]; then
  echo "invalid 'WITH_BRAKEMAN' value ($WITH_BRAKEMAN)" >&2
  exit 1
fi

if [[ "$WITH_BRAKEMAN" == "true" ]]; then
  echo "should_run=true"
  exit 0
fi

if [[ "$WITH_BRAKEMAN" == "false" ]]; then
  echo "should_run=false"
  exit 0
fi

# Check if brakeman is available in the bundle
if bundle exec brakeman --version &>/dev/null; then
  echo "should_run=true"
  exit 0
fi

echo "should_run=false"
