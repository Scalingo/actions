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

  local api_url="https://api.github.com/repos/LuaLS/lua-language-server/releases/latest"
  local auth_header=()
  if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    auth_header=(--header "Authorization: Bearer ${GITHUB_TOKEN}")
  fi

  local latest_tag
  latest_tag=$(
    curl --fail --silent --show-error --location \
      --header "Accept: application/vnd.github+json" \
      "${auth_header[@]}" \
      "${api_url}" |
      python - <<'PY'
import json, sys
data = json.load(sys.stdin)
tag = data.get("tag_name") or data.get("name")
if not tag:
    sys.exit("Unable to determine latest lua-language-server release tag")
print(tag.lstrip("v"))
PY
  )

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
curl --fail --silent --show-error --location "${ARCHIVE_URL}" | tar --extract --gzip --strip-components=1 --directory "${CACHE_DIR}"

echo "${VERSION}" > "${VERSION_FILE}"
"${CACHE_DIR}/bin/lua-language-server" --version
