#!/bin/sh

set -o errexit
set -o nounset


# Build flags:
set -- "--severity=${SEVERITY}" "--shell=bash"

if [ "${ALL_CHECKS:-false}" = "true" ]; then
	set -- "${@}" "--enable=all"
fi

# Run Shellcheck:
if [ -n "${FILES}" ]; then
	# Intentionally split FILES and expand globs.
	# Spaces in filenames are not supported.
	# shellcheck disable=SC2086
	shellcheck "$@" -- ${FILES}
else
	# Default behavior
	# Finds all .sh files and pass them to ShellCheck.
	# Ignores those in the `.git` directory.
	find . -type f -name '*.sh' -not -path './.git/*' \
		-exec shellcheck "$@" -- {} +
fi
