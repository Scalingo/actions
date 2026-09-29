#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

# Use temporary file so a writing failure doesn't corrupt the inventory.
# We use atomic operation (e.g. `mv`) to create the updated inventory file.
tmp_inventory=""
new_inventory=""

cleanup() {
	rm --force -- "${tmp_inventory}" "${new_inventory}"
}

trap cleanup EXIT

tmp_inventory="$( mktemp -- "${INVENTORY}.tmp.XXXXXX" )" || exit 1
new_inventory="$( mktemp -- "${INVENTORY}.new.XXXXXX" )" || exit 1

# -----------------------------------------------------------------------------

inventory::check_and_add_new_releases() {
#
# Compares the releases table read from stdin with what's already in the
# inventory file.
# If a new version is detected, append it to the inventory file.
#

	local -A known_versions=()
	local version
	local url
	local sha256
	local header
	local _

	# Load existing versions once in $known_versions, skipping the header.
	# Mind the block structure allowing to take the file as input.
	{
		# Skip header row:
		IFS= read -r header

		# Populate $known_versions
		while IFS=$'\t' read -r version _ || [[ -n "${version}" ]]; do
			[[ -n "${version}" ]] || continue

			known_versions["${version}"]=1
		done
	} < "${tmp_inventory}"

	# Now that $known_versions is populated, check if we have new releases:
	while IFS=$'\t' read -r version url sha256 || [[ -n "${version}" ]]; do
		# Skip row if it doesn't have a version:
		[[ -n "${version}" ]] || continue

		# Skip row if version is already known:
		if [[ -n "${known_versions["${version}"]:-}" ]]; then
			continue
		fi

		# Add version to releases:
		printf '%s\t%s\t%s\t\n' "${version}" "${url}" "${sha256}" \
			>> "${tmp_inventory}"

		# Update $known_versions with this version:
		known_versions["${version}"]=1
	done
}

inventory::sort() {
#
# Sorts the inventory by version number.
# Sorting order defaults to DESC.
#

	local inventory="${1}"
	local sort_order="${2:-"DESC"}"
	local opts=()

	# The case statement makes it explicit we only accept "ASC" or "DESC"
	# as sorting order.
	case "${sort_order}" in
		"ASC")
			# Do nothing
			;;
		"DESC")
			opts+=("--reverse")
			;;
		*)
			printf "Sort order MUST be either 'ASC' or 'DESC'. %s given.\n" \
				"${sort_order}" >&2
			return 1
			;;
	esac

	# Prints inventory header
	head --lines=1 -- "${inventory}"

	# Skips the first line (header), and sorts the remaining lines:
	tail --lines=+2 -- "${inventory}" \
		| sort --field-separator=$'\t' --key=1,1 --version-sort "${opts[@]}"
}

inventory::remove_empty_lines() (
#
# /!\
# This function is written between parentheses!
# Parentheses run this function in a subshell, isolating its EXIT trap from
# the script's cleanup trap. The temporary file is removed when the subshell
# exits, while the local tmp variable is still available.
#
# Removes completely empty lines, and lines containing only
# control/non-printable characters such as \r, tabs, NULs, whitespaces, etc.
#

	local file="${1}"
	local tmp

	tmp="$( mktemp )" || return 1
	# Make sure we cleanup after ourselves:
	trap 'rm --force -- "${tmp}"' EXIT

	# Treat NUL-containing input as text. Keep lines containing at least
    # one printable, non-whitespace character.
	if LC_ALL=C grep --text '[[:graph:]]' -- "${file}" > "${tmp}"; then
		:
	else
		status="${?}"
		# Status 1 means no matching lines, which is OK.
		# Other statuses indicate an actual error.
		if (( status != 1 )); then
			return "${status}"
		fi
	fi

	cat -- "${tmp}" > "${file}"
)

inventory::set_default_version() {
#
# Reads the sorted inventory from stdin, sets the default version, and writes
# the result to stdout, preserving the header.
# Input must be sorted by version descending: the first release matching
# the requested major is marked as default, so it must be the newest one.
#

	local target_major="${1}"
	local header_row
	local seen_default=""
	local version
	local url
	local sha256
	local default
	local major

	# Read first line (header):
	IFS= read -r header_row

	# Prints the header:
	printf '%s\n' "${header_row}"

	while IFS=$'\t' read -r version url sha256 default; do
		major="${version%%.*}"
		default=""

		if [[ -z "${seen_default:-}" ]] \
			&& [[ "${major}" = "${target_major}" ]]
		then
			default="default"
			seen_default=1
		fi

		printf '%s\t%s\t%s\t%s\n' \
			"${version}" "${url}" "${sha256}" "${default}"
	done
}

# -----------------------------------------------------------------------------

# The inventory file should end up with one single row set as default.
# To allow this script identify this default row, two variables are provided:
# - $MAJORS: a space-separated string with all majors versions to put in the
#   inventory file.
# - $DEFAULT_MAJOR: a single value specifying wich major version to consider
#   as the default one.
#
# If $DEFAULT_MAJOR is not set, or if its value is not in $MAJORS, the highest
# value of $MAJORS is considered as the default one.

# Get the list of allowed major versions, sorted descending:
major_versions="$( printf '%s\n' "${MAJORS:-}" \
					| tr --squeeze-repeats '[:space:]' '\n' \
					| sort --version-sort --reverse )"

# In last resort, the default major version is the highest available.
# Since $major_versions is sorted descending, it's the first value:
default_major="${major_versions%%$'\n'*}"

# Accept DEFAULT_MAJOR only when it matches a value set in MAJORS:
while IFS= read -r major; do
	if [[ -n "${major}" && "${major}" = "${DEFAULT_MAJOR:-}" ]]; then
		default_major="${major}"
		break
	fi
done <<< "${major_versions}"


if [[ ! -f "${INVENTORY}" ]]; then
	# Create inventory file:
	printf '%s\t%s\t%s\t%s\n' \
		"Version" "URL" "Checksum" "Default?" > "${INVENTORY}"
fi

# Put inventory file aside:
cp -- "${INVENTORY}" "${tmp_inventory}" >/dev/null

# Ensures the file ends with a newline char, so we can safely append a new row.
# The `-s` check ensures the file is not empty.
if [[ -s "${tmp_inventory}" ]]; then
	printf '\n' >> "${tmp_inventory}"
fi

# Check for new releases:
inventory::check_and_add_new_releases

# Removes empty lines from the file:
inventory::remove_empty_lines "${tmp_inventory}"

# Build and replace the final inventory:
inventory::sort "${tmp_inventory}" "DESC" \
	| inventory::set_default_version "${default_major}" > "${new_inventory}"

# Move updated inventory back in place, preserve orginal permissions:
chmod u+r -- "${new_inventory}"
mv -- "${new_inventory}" "${INVENTORY}"
