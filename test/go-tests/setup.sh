#!/usr/bin/env bash

set -euo pipefail

cur_dir=$(cd "$(dirname "$0")" && pwd)
target_directory="${1:-${GITHUB_WORKSPACE}}"

mkdir -p "$target_directory"
cd "$cur_dir"

cp -R ./{go.mod,go.sum,main.go,vendor} "$target_directory"
