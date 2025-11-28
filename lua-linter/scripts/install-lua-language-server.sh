#!/usr/bin/env bash
set -euo pipefail

REQUESTED_VERSION="${LUALS_VERSION:-latest}"
CACHE_DIR="${HOME}/.cache/lua-language-server"
VERSION_FILE="${CACHE_DIR}/VERSION"

resolve_version() {
  local version="${REQUESTED_VERSION}"
  if [[ "${REQUESTED_VERSION}" != "latest" ]]; then
    echo "${version}"
    return
  fi

  # Resolve via the public redirect
  local latest_tag=""
  latest_tag=$(
    curl --fail --silent --head --location https://github.com/LuaLS/lua-language-server/releases/latest \
      | awk '/^location:/ {print $2}' \
      | tr -d '\r' \
      | sed -n 's#.*/tag/v\{0,1\}\([0-9][^/]*\)#\1#p'
  ) || latest_tag=""

  if [[ -z "${latest_tag}" ]]; then
    echo "Error: failed to resolve latest lua-language-server release" >&2
    exit 1
  fi

  echo "${latest_tag}"
}

VERSION="$(resolve_version)"
ARCHIVE_URL="https://github.com/LuaLS/lua-language-server/releases/download/${VERSION}/lua-language-server-${VERSION}-linux-x64.tar.gz"

if [[ -x "${CACHE_DIR}/bin/lua-language-server" ]] && [[ -f "${VERSION_FILE}" ]] && [[ "$(cat "${VERSION_FILE}")" == "${VERSION}" ]]; then
  echo "lua-language-server ${VERSION} already present in cache"
  exit 0
fi

rm --recursive --force "${CACHE_DIR}"
mkdir --parents "${CACHE_DIR}"

echo "Downloading lua-language-server ${VERSION}"
curl --fail --silent --show-error --location "${ARCHIVE_URL}" | tar --extract --gzip --directory "${CACHE_DIR}"

echo "${VERSION}" > "${VERSION_FILE}"
"${CACHE_DIR}/bin/lua-language-server" --version
