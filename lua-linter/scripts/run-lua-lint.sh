#!/usr/bin/env bash
set -euo pipefail

CHECKLEVEL="${CHECKLEVEL:-Hint}"
LUALS_BIN="${RUNNER_TEMP:-/tmp}/lua-language-server/bin/lua-language-server"

if [[ ! -x "${LUALS_BIN}" ]]; then
  echo "lua-language-server binary not found at ${LUALS_BIN}"
  exit 1
fi

"${LUALS_BIN}" --check "${PWD}" --checklevel="${CHECKLEVEL}"
