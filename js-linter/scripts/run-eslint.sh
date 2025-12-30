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

# Check if a script exists in package.json
has_script() {
  local script="$1"
  [[ -f "package.json" ]] && jq -e ".scripts.\"$script\"" package.json > /dev/null 2>&1
}

# Determine which lint command to run
if has_script "lint"; then
  echo "Running lint script from package.json..."
  run_cmd lint
elif has_script "eslint"; then
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
