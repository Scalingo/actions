#!/usr/bin/env bash
#
# Common script to check if a tool should be executed
# Usage: check-tool.sh <env_var_name> <detection_command>
#
# Arguments:
#   env_var_name: Name of the environment variable to check (e.g., WITH_RUBOCOP)
#   detection_command: Command to run for auto-detection
#
# This script writes to stdout what needs to be redirected to GITHUB_OUTPUT to set the variable should_run.
#

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <env_var_name> <detection_command>" >&2
  exit 1
fi

ENV_VAR_NAME="$1"
DETECTION_COMMAND="$2"

# Get the value from the environment variable
ENV_VALUE="${!ENV_VAR_NAME}"

if [[ -z "$ENV_VALUE" ]]; then
  echo "Usage: $0" >&2
  echo "$ENV_VAR_NAME environment variable must be set with one of the following value: true | false | auto" >&2
  exit 1
fi

if [[ "$ENV_VALUE" != "true" ]] && [[ "$ENV_VALUE" != "false" ]] && [[ "$ENV_VALUE" != "auto" ]]; then
  echo "invalid '$ENV_VAR_NAME' value ($ENV_VALUE)" >&2
  exit 1
fi

if [[ "$ENV_VALUE" == "true" ]]; then
  echo "should_run=true"
  exit 0
fi

if [[ "$ENV_VALUE" == "false" ]]; then
  echo "should_run=false"
  exit 0
fi

# Auto-detection mode
if eval "$DETECTION_COMMAND" &>/dev/null; then
  echo "should_run=true"
  exit 0
fi

echo "should_run=false"
