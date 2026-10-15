#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail


# Use temporary file so a writing failure doesn't corrupt the inventory.
# We use atomic operation (e.g. `mv`) to create the updated inventory file.
tmp_inventory=""
new_inventory=""
declare -A new_versions=()


cleanup() {
	rm --force -- "${tmp_inventory}" "${new_inventory}"
}

trap cleanup EXIT


tmp_inventory="$( mktemp -- "${INVENTORY}.tmp.XXXXXX" )" || exit 1
new_inventory="$( mktemp -- "${INVENTORY}.new.XXXXXX" )" || exit 1

# -----------------------------------------------------------------------------

inventory::sort() {
#
# Reads the inventory from stdin and prints it sorted by version to stdout.
# Sorting order defaults to DESC.
#

	local sort_order="${1:-"DESC"}"
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

	sort --field-separator=$'\t' --key=1,1 --version-sort "${opts[@]}"
}

inventory::remove_empty_lines() {
#
# Reads stdin and removes empty lines and lines containing only whitespace
# or non-printable characters. The result is printed on stdout.
#
	local status

	# Treat NUL-containing input as text. Keep lines containing at least
	# one printable, non-whitespace character.
	if LC_ALL=C grep --text '[[:graph:]]'; then
		return 0
	else
		status="${?}"
		# Status 1 means no matching lines, which is OK.
		# Other statuses indicate an actual error.
		if (( status != 1 )); then
			return "${status}"
		fi
	fi
}

inventory::check_and_add_new_releases() {
#
# Reads one release version per line from stdin and compares it with the
# existing inventory.
# If a new version is detected, append it to the inventory file.
#

	local -A known_versions=()
	local version
	local _

	# Load existing versions once in $known_versions.
	# Mind the block structure allowing to take the file as input.
	{
		# Populate $known_versions
		while IFS=$'\t' read -r version _ || [[ -n "${version}" ]]; do
			[[ -n "${version}" ]] || continue

			known_versions["${version}"]=1
		done
	} < "${tmp_inventory}"

	# Now that $known_versions is populated, check if we have new releases:
	while IFS= read -r version || [[ -n "${version}" ]]; do
		# Skip row if it doesn't have a version:
		[[ -n "${version}" ]] || continue

		# Skip row if version is already known:
		if [[ -n "${known_versions["${version}"]:-}" ]]; then
			continue
		fi

		# For now we just need to add the version to the inventory:
		printf '%s\n' "${version}" >> "${tmp_inventory}"

		# Update $known_versions with this version:
		known_versions["${version}"]=1
		new_versions["${version}"]=1
	done
}

inventory::keep_latest_revisions() {
#
# Reads an inventory sorted by version descending and keeps the first row
# for each numeric major.minor.patch base, regardless of its suffix.
# For example, 13.0.1+security-02 supersedes both
# 13.0.1+security-01 and 13.0.1.
#

	local -A seen_versions=()
	local row
	local version
	local base_version

	while IFS= read -r row || [[ -n "${row}" ]]; do
		version="${row%%$'\t'*}"
		# Keep unrecognized existing versions distinct rather than grouping
		# them under an empty base version.
		base_version="${version}"
		if [[ "${version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+ ]]; then
			base_version="${BASH_REMATCH[0]}"
		fi

		if [[ -n "${seen_versions["${base_version}"]:-}" ]]; then
			continue
		fi

		seen_versions["${base_version}"]=1
		printf '%s\n' "${row}"
	done
}

inventory::limit_releases() (
#
# /!\
# This function is written between parentheses!
# Parentheses run this function in a subshell, isolating its EXIT trap from
# the script's cleanup trap.
# The temporary files are removed when the subshell exits.
#
# Reads the inventory from stdin, and keeps the newest N entries for each
# requested version series (major or major.minor).
# Keeps only requested version series.
#
# The updated inventory is printed on stdout.
#

	local limit="${1:-}"
	local inventory=""
	local series_file=""
	local series
	local status

	# Use a subshell to keep this cleanup separate from the script's EXIT trap.
	trap 'rm --force -- "${inventory}" "${series_file}"' EXIT
	inventory="$( mktemp )" || return 1
	series_file="$( mktemp )" || return 1

	# Buffer stdin in $inventory so each requested series can read the complete
	# inventory
	cat > "${inventory}" || return 1

	for series in ${SERIES}; do
		# Put all rows for this series aside (in $series_file)
		if grep --extended-regexp "^${series//./\\.}\." "${inventory}" \
			> "${series_file}"
		then
			# Apply release limit:
			if [[ -n "${limit:-}" ]]; then
				# Limit to $limit releases for this series:
				head --lines "${limit}" -- "${series_file}"
			else
				# No limit:
				cat -- "${series_file}"
			fi
		else
			# Return if grep failed
			# grep returns 1 when no match could be found, which is OK
			status="${?}"
			(( status == 1 )) || return "${status}"
		fi
	done
)

inventory::build_new_rows() {
#
# Download only new versions retained in the final inventory.
# Existing rows (including manually corrected checksums) are preserved.
# A failed or incomplete download leaves FIXME rather than a partial checksum.
#
# Uses `$new_versions` filled in `inventory::check_and_add_new_releases`
#

	local version_placeholder="{version}"
	local row
	local version
	local url
	local checksum

	# Read the file line by line
	while IFS= read -r row || [[ -n "${row}" ]]; do

		version="${row%%$'\t'*}"

		if [[ -z "${new_versions["${version}"]:-}" ]]; then
			# This version is known, print the row and go on
			printf '%s\n' "${row}"
			continue
		fi

		# Replace every placeholder literally to build the URL
		url="${DOWNLOAD_URL//"${version_placeholder}"/"${version}"}"

		# Compute archive checksum
		# pipefail ensures that curl errors are detected even if sha256sum
		# successfully hashes an empty or partially downloaded response.
		if checksum="$( curl --fail --location --silent --show-error \
			--globoff --connect-timeout 30 --max-time 600 -- "${url}" \
			| sha256sum )"
		then
			# Removes everything after the first space char,
			# so we keep the hex-digest only
			checksum="sha256:${checksum%% *}"
		else
			checksum="FIXME"
		fi

		printf '%s\t%s\t%s\t\n' \
			"${version}" "${url}" "${checksum}"
	done
}

inventory::set_default_version() {
#
# Reads the sorted inventory from stdin, sets the default version, and writes
# the result to stdout.
# Input must be sorted by version descending: the first release matching
# the requested series is marked as default, so it must be the newest one.
#

	local target_series="${1}"
	local version
	local url
	local checksum
	local default
	local seen_default=""

	while IFS=$'\t' read -r version url checksum default; do
		default=""

		if [[ -z "${seen_default:-}" ]] \
			&& [[ "${version}" == "${target_series}."* ]]
		then
			default="default"
			seen_default=1
		fi

		printf '%s\t%s\t%s\t%s\n' \
			"${version}" "${url}" "${checksum}" "${default}"
	done
}

# -----------------------------------------------------------------------------

# The inventory file should end up with one single row set as default.
# To allow this script identify this default row, two variables are provided:
# - $SERIES: whitespace-separated major or major.minor selectors, optionally
#   ending in .x, to put in the inventory file.
# - $DEFAULT_SERIES: a selector specifying which series to use as the default.
#
# If $DEFAULT_SERIES is not set, or if its value is not in $SERIES, the highest
# value of $SERIES is considered as the default one.

# Normalize SERIES to one value per line, sorted descending without duplicates.
SERIES="$( printf '%s\n' "${SERIES:-}" \
					| tr --squeeze-repeats '[:space:]' '\n' \
					| inventory::remove_empty_lines \
					| sed 's/\.x$//' \
					| sort --version-sort --reverse --unique )"

DEFAULT_SERIES="${DEFAULT_SERIES:-}"
DEFAULT_SERIES="${DEFAULT_SERIES%.x}"

# In last resort, the default series is the highest available.
# Since $SERIES is sorted descending, it's the first value:
default_series="${SERIES%%$'\n'*}"

# Accept DEFAULT_SERIES only when it matches a value set in SERIES:
while IFS= read -r series; do
	if [[ -n "${series}" && "${series}" = "${DEFAULT_SERIES:-}" ]]; then
		default_series="${series}"
		break
	fi
done <<< "${SERIES}"


# Create inventory file if it doesn't exist yet:
if [[ ! -s "${INVENTORY}" ]]; then
	touch "${INVENTORY}"
fi

# Put inventory file aside:
cp -- "${INVENTORY}" "${tmp_inventory}" >/dev/null

# Remove header from $tmp_inventory:
tail -n +2 -- "${tmp_inventory}" > "${tmp_inventory}.tmp" \
	&& mv -- "${tmp_inventory}.tmp" "${tmp_inventory}"

# Ensures the file ends with a newline char, so we can safely append a new row.
# The `-s` check ensures the file is not empty.
if [[ -s "${tmp_inventory}" ]]; then
	printf '\n' >> "${tmp_inventory}"
fi

# Prepares the final inventory by adding the header row:
printf "%s\t%s\t%s\t%s\n" "Version" "URL" "Checksum" "Default?" \
	> "${new_inventory}"

# Check for new releases:
inventory::check_and_add_new_releases

# Build and replace the final inventory:
# 1. Removes blank rows before processing versions
# 2. Puts newest versions first for revision selection and release limits
# 3. Removes superseded revisions so they don't consume release limits
# 4. Emits a separate block for each requested series
#    Overlapping selectors can duplicate rows and disrupt global ordering
# 5. Restores ordering
# 6. Removes duplicates
# 7. Build new rows (URL, checksum)
# 8. Marks the default version
inventory::remove_empty_lines < "${tmp_inventory}" \
	| inventory::sort "DESC" \
	| inventory::keep_latest_revisions \
	| inventory::limit_releases "${RELEASES_LIMIT:-}" \
	| inventory::sort "DESC" \
	| uniq \
	| inventory::build_new_rows \
	| inventory::set_default_version "${default_series}" \
	>> "${new_inventory}"

# Move updated inventory back in place, preserve orginal permissions:
chmod 0644 -- "${new_inventory}"
mv -- "${new_inventory}" "${INVENTORY}"
