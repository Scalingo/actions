#!/usr/bin/env bash
set -euo pipefail

VERSION="${LUACHECK_VERSION:-}"
LUA_VERSION="${LUACHECK_LUA_VERSION:-5.1}"
LUAROCKS_TREE="${HOME}/.cache/luacheck"
LUACHECK_BIN="${LUAROCKS_TREE}/bin/luacheck"

if [[ -x "${LUACHECK_BIN}" ]]; then
  echo "luacheck already present in cache"
  "${LUACHECK_BIN}" --version
  exit 0
fi

if ! command -v luarocks >/dev/null 2>&1; then
  echo "Installing luarocks (lua and luarocks not found)"
  sudo apt-get update
  sudo apt-get install -y luarocks
fi

mkdir -p "${LUAROCKS_TREE}"
INSTALL_ARGS=(--lua-version="${LUA_VERSION}" --tree "${LUAROCKS_TREE}" install luacheck)
if [[ -n "${VERSION}" ]]; then
  INSTALL_ARGS+=("${VERSION}")
fi

if ! luarocks "${INSTALL_ARGS[@]}"; then
  if [[ -n "${VERSION}" ]]; then
    echo "luacheck version ${VERSION} unavailable for Lua ${LUA_VERSION}, retrying latest"
    luarocks --lua-version="${LUA_VERSION}" --tree "${LUAROCKS_TREE}" install luacheck
  else
    exit 1
  fi
fi

echo "${LUAROCKS_TREE}/bin" >> "${GITHUB_PATH}"
"${LUACHECK_BIN}" --version
