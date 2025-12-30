#!/usr/bin/env bash
#
# Run ESLint on the codebase
#

set -euo pipefail

PACKAGE_MANAGER="${PACKAGE_MANAGER:-npm}"

run_cmd() {
  if [[ "$PACKAGE_MANAGER" == "yarn" ]]; then
    yarn "$@"
  else
    npm run "$@"
  fi
}

# Determine which lint command to run
if [[ -f "package.json" ]] && grep -q '"lint"' package.json; then
  echo "Running lint script from package.json..."
  run_cmd lint
elif [[ -f "package.json" ]] && grep -q '"eslint"' package.json; then
  echo "Running eslint script from package.json..."
  run_cmd eslint
else
  echo "No lint script found, running ESLint directly..."
  if [[ "$PACKAGE_MANAGER" == "yarn" ]]; then
    yarn run eslint .
  else
    npx eslint .
  fi
fi
