#!/usr/bin/env bash
set -euo pipefail

CHECKLEVEL="${CHECKLEVEL:-Hint}"
LUA_PATH="${LUA_PATH:-}"
LUAROCKS_TREE="${LUAROCKS_TREE:-}"
LUALS_BIN="${HOME}/.cache/lua-language-server/bin/lua-language-server"

if [[ -z "${LUA_PATH}" ]] && command -v luarocks >/dev/null 2>&1; then
  if [[ -n "${LUAROCKS_TREE}" ]]; then
    eval "$(luarocks --tree "${LUAROCKS_TREE}" path)"
  else
    eval "$(luarocks path)"
  fi
fi

if [[ -n "${LUA_PATH}" ]]; then
  echo "Using LUA_PATH=${LUA_PATH}"
fi

if [[ ! -x "${LUALS_BIN}" ]]; then
  echo "lua-language-server binary not found at ${LUALS_BIN}"
  exit 1
fi

"${LUALS_BIN}" --check "${PWD}" --checklevel="${CHECKLEVEL}"
