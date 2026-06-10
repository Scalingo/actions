#!/bin/sh

set -o errexit
set -o nounset

if [ -n "${FILES}" ]; then
	# Reset argv ($@):
	set --

	# Fill argv with the files provided. Keeps spaces.
	while IFS= read -r file; do
		[ -n "${file}" ] && set -- "$@" "${file}"
	done <<-EOF
	${FILES}
	EOF

	# Run ShellCheck
	shellcheck -S "${SEVERITY}" -s bash "$@"
else
	# Default behavior
	# Finds all .sh files and pass them to ShellCheck.
	# Ignores those in the `.git` directory.
	find . -type f -name '*.sh' -not -path './.git/*' \
		-exec shellcheck -S "${SEVERITY}" -s bash {} +
fi
