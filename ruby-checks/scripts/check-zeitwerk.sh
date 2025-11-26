#!/usr/bin/env bash
#
# Check if Zeitwerk check should be executed
# WITH_ZEITWERK is set in the environment by the calling GitHub Action.
# This script writes to stdout what needs to be redirected to GITHUB_OUTPUT to set the variable should_run.
#

if [[ $# -ne 0 ]] || [[ -z "$WITH_ZEITWERK" ]]; then
  echo "Usage: $0" >&2
  echo "WITH_ZEITWERK environment variable must be set with one of the following value: true | false | auto" >&2
  exit 1
fi

if [[ "$WITH_ZEITWERK" != "true" ]] && [[ "$WITH_ZEITWERK" != "false" ]] && [[ "$WITH_ZEITWERK" != "auto" ]]; then
  echo "invalid 'WITH_ZEITWERK' value ($WITH_ZEITWERK)" >&2
  exit 1
fi

if [[ "$WITH_ZEITWERK" == "true" ]]; then
  echo "should_run=true"
  exit 0
fi

if [[ "$WITH_ZEITWERK" == "false" ]]; then
  echo "should_run=false"
  exit 0
fi

# Check if the zeitwerk:check rake task exists
if bundle exec rake --tasks 2>/dev/null | grep --quiet "zeitwerk:check"; then
  echo "should_run=true"
  exit 0
fi

echo "should_run=false"
