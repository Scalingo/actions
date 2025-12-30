#!/usr/bin/env bash
#
# Run ESLint on the codebase
#

set -euo pipefail

PACKAGE_MANAGER="${PACKAGE_MANAGER:-npm}"

# Check if there's a lint or eslint script in package.json
if [[ -f "package.json" ]] && grep -q '"lint"' package.json; then
  echo "Running lint script from package.json..."
  if [[ "$PACKAGE_MANAGER" == "yarn" ]]; then
    yarn lint
  else
    npm run lint
  fi
elif [[ -f "package.json" ]] && grep -q '"eslint"' package.json; then
  echo "Running eslint script from package.json..."
  if [[ "$PACKAGE_MANAGER" == "yarn" ]]; then
    yarn eslint
  else
    npm run eslint
  fi
else
  echo "No lint script found, running ESLint directly..."
  if [[ "$PACKAGE_MANAGER" == "yarn" ]]; then
    yarn run eslint .
  else
    npx eslint .
  fi
fi
