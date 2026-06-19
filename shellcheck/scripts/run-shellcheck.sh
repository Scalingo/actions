#!/bin/sh

set -o errexit
set -o nounset

if [ -n "${FILES}" ]; then
	# Reset argv ($@):
	# FILES is newline-separated and globbing is allowed.
	# Spaces in filenames are intentionally not supported.
	# shellcheck disable=SC2086
	set -- ${FILES}

	# Run ShellCheck
	shellcheck --severity="${SEVERITY}" --shell=bash -- "$@"
else
	# Default behavior
	# Finds all .sh files and pass them to ShellCheck.
	# Ignores those in the `.git` directory.
	find . -type f -name '*.sh' -not -path './.git/*' \
		-exec shellcheck --severity="${SEVERITY}" --shell=bash -- {} +
fi
