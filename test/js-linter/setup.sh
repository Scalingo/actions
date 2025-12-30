#!/usr/bin/env bash

set -euo pipefail

cur_dir=$(cd "$(dirname "$0")" && pwd)
cd "$cur_dir"

cp -R ./{package.json,package-lock.json,.eslintrc.js,.node-version} "${GITHUB_WORKSPACE}"
