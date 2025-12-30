#!/usr/bin/env bash
#
# Check if ESLint should be executed
# WITH_ESLINT is set in the environment by the calling GitHub Action.
# This script writes to stdout what needs to be redirected to GITHUB_OUTPUT.
#

set -euo pipefail

# Detection: look for .eslintrc* files, eslint.config.* or eslint in package.json
check_eslint_available() {
  # Check for ESLint config files
  if ls .eslintrc* >/dev/null 2>&1 || [[ -f "eslint.config.js" ]] || [[ -f "eslint.config.mjs" ]] || [[ -f "eslint.config.cjs" ]]; then
    return 0
  fi
  # Check if eslint is in package.json devDependencies or dependencies
  if [[ -f "package.json" ]] && grep -q '"eslint"' package.json; then
    return 0
  fi
  return 1
}

if [[ -z "${WITH_ESLINT:-}" ]]; then
  echo "WITH_ESLINT environment variable must be set" >&2
  exit 1
fi

case "$WITH_ESLINT" in
  true)
    echo "should_run=true"
    ;;
  false)
    echo "should_run=false"
    ;;
  auto)
    if check_eslint_available; then
      echo "should_run=true"
    else
      echo "should_run=false"
    fi
    ;;
  *)
    echo "Invalid WITH_ESLINT value: $WITH_ESLINT" >&2
    exit 1
    ;;
esac
