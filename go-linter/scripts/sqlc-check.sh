#!/usr/bin/env bash
#
# Check the WITH_SQLC value to determine whether sqlc needs to be installed or not.
# WITH_SQLC is set in the environment by the calling GitHub Action.
# This script writes on stdout what needs to be redirected to GITHUB_OUTPUT to set the variable configuration_file.
#

if [[ $# -ne 0 ]] || [[ -z "$WITH_SQLC" ]]; then
  echo "Usage: $0" >&2
  echo "WITH_SQLC environment variable must be set with one of the following value: true | false | auto" >&2
  exit 1
fi

if [[ "$WITH_SQLC" != "true" ]] && [[ "$WITH_SQLC" != "false" ]] && [[ "$WITH_SQLC" != "auto" ]]; then
  echo "invalid 'WITH_SQLC' value ($WITH_SQLC)" >&2
  exit 1
fi

if [[ "$WITH_SQLC" == "false" ]]; then
  exit 0
fi

configuration_file=$(find . -name "sqlc.yml")

if [[ "$WITH_SQLC" == "true" ]] && [[ -z "$configuration_file" ]]; then
  echo "Fail to find the sqlc configuration file" >&2
  exit 1
fi

echo "configuration_file=$configuration_file"
