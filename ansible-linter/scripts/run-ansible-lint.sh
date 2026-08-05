#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

cd "${GITHUB_WORKSPACE:?GITHUB_WORKSPACE must be set}"

if [ -n "${FILES//[$'\t\n\r ']/}" ]; then
	# Reset argv ($@):
	# FILES is newline-separated and globbing is allowed.
	# Spaces in filenames are intentionally not supported.
	# shellcheck disable=SC2086
	set -- ${FILES}
else
	set --
fi

if [ "$#" -eq 0 ]; then
	cd "${WORKING_DIRECTORY:?WORKING_DIRECTORY must be set}"
	# shellcheck disable=SC2086
	ansible-lint ${ARGS}
	exit 0
fi

declare -a files=()

for file in "$@"; do
	files+=("${GITHUB_WORKSPACE:?GITHUB_WORKSPACE must be set}/${file}")
done

cd "${WORKING_DIRECTORY:?WORKING_DIRECTORY must be set}"

# Keep args compatible with the upstream action while letting the shell expand
# repo-root-relative file globs before invoking ansible-lint.
# shellcheck disable=SC2086
ansible-lint ${ARGS} -- "${files[@]}"
