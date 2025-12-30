#!/usr/bin/env bash
#
# Detect which package manager to use (npm or yarn)
# Outputs: manager=npm|yarn
#

set -euo pipefail

if [[ -f "yarn.lock" ]]; then
  echo "manager=yarn"
elif [[ -f "package-lock.json" ]]; then
  echo "manager=npm"
elif [[ -f "package.json" ]]; then
  # Default to npm if no lock file but package.json exists
  echo "manager=npm"
else
  echo "No package.json found" >&2
  exit 1
fi
