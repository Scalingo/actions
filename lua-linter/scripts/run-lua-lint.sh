#!/usr/bin/env bash
set -euo pipefail

CHECKLEVEL="${CHECKLEVEL:-Hint}"
LUA_PATH="${LUA_PATH:-}"
LUALS_BIN="${RUNNER_TEMP:-/tmp}/lua-language-server/bin/lua-language-server"

if [[ -n "${LUA_PATH}" ]]; then
  echo "Using LUA_PATH=${LUA_PATH}"
  export LUA_PATH
fi

if [[ ! -x "${LUALS_BIN}" ]]; then
  echo "lua-language-server binary not found at ${LUALS_BIN}"
  exit 1
fi

"${LUALS_BIN}" --check "${PWD}" --checklevel="${CHECKLEVEL}"
