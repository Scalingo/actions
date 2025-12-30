#!/usr/bin/env bash
#
# Run ESLint on the codebase
#

set -euo pipefail

PACKAGE_MANAGER="${PACKAGE_MANAGER:-npm}"

# Check if there's a lint script in package.json
if [[ -f "package.json" ]] && grep -q '"lint"' package.json; then
  echo "Running lint script from package.json..."
  if [[ "$PACKAGE_MANAGER" == "yarn" ]]; then
    yarn lint
  else
    npm run lint
  fi
else
  echo "Running ESLint directly..."
  if [[ "$PACKAGE_MANAGER" == "yarn" ]]; then
    yarn run eslint .
  else
    npx eslint .
  fi
fi
