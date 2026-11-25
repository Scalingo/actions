#!/usr/bin/env bash

set -euo pipefail

touch .scalingo-ci-extra-linter-ran

if [[ "${SCALINGO_GO_LINTER_EXTRA_SCRIPT_FAIL:-false}" == "true" ]]; then
  exit 1
fi
