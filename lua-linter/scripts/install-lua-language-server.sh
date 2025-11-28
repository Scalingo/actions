#!/usr/bin/env bash
set -euo pipefail

CACHE_DIR="${HOME}/.cache/lua-language-server"

# Check if cached version exists
if [[ -x "${CACHE_DIR}/bin/lua-language-server" ]]; then
  echo "lua-language-server already present in cache"
  "${CACHE_DIR}/bin/lua-language-server" --version
  exit 0
fi

# Resolve latest version via GitHub's redirect
VERSION=$(
  curl --fail --silent --head --location "https://github.com/LuaLS/lua-language-server/releases/latest" \
    | awk --field-separator '/' '/^location:/ {print $NF}' \
    | tr --delete '\r'
)

if [[ -z "${VERSION}" ]]; then
  echo "Error: failed to resolve latest lua-language-server version" >&2
  exit 1
fi

ARCHIVE_URL="https://github.com/LuaLS/lua-language-server/releases/download/${VERSION}/lua-language-server-${VERSION}-linux-x64.tar.gz"

rm --recursive --force "${CACHE_DIR}"
mkdir --parents "${CACHE_DIR}"

echo "Downloading lua-language-server ${VERSION}"
curl --fail --silent --show-error --location "${ARCHIVE_URL}" | tar --extract --gzip --directory "${CACHE_DIR}"

"${CACHE_DIR}/bin/lua-language-server" --version
