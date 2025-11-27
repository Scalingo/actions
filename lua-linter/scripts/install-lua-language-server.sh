#!/usr/bin/env bash
set -euo pipefail

VERSION="${LUALS_VERSION:-3.15.0}"
CACHE_DIR="${HOME}/.cache/lua-language-server"
ARCHIVE_URL="https://github.com/LuaLS/lua-language-server/releases/download/${VERSION}/lua-language-server-${VERSION}-linux-x64.tar.gz"

if [[ -x "${CACHE_DIR}/bin/lua-language-server" ]]; then
  echo "lua-language-server already present in cache"
  exit 0
fi

rm -rf "${CACHE_DIR}"
mkdir -p "${CACHE_DIR}"

echo "Downloading lua-language-server ${VERSION}"
curl -fsSL "${ARCHIVE_URL}" | tar -xz --strip-components=1 -C "${CACHE_DIR}"

"${CACHE_DIR}/bin/lua-language-server" --version
