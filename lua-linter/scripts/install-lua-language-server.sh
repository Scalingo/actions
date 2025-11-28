#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="${RUNNER_TEMP:-/tmp}/lua-language-server"

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

rm --recursive --force "${INSTALL_DIR}"
mkdir --parents "${INSTALL_DIR}"

echo "Downloading lua-language-server ${VERSION}"
curl --fail --silent --show-error --location "${ARCHIVE_URL}" | tar --extract --gzip --directory "${INSTALL_DIR}"

"${INSTALL_DIR}/bin/lua-language-server" --version
