#!/usr/bin/env bash

set -euo pipefail

cur_dir=$(cd "$(dirname "$0")" && pwd)
cd "$cur_dir"

cp -R ./{go.mod,go.sum,main.go,vendor} "${GITHUB_WORKSPACE}"
