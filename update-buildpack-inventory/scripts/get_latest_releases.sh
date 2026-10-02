#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

gh api "repos/${REPOSITORY}/releases" --paginate \
	| jq --raw-output --arg majors "${MAJORS}" '
		#
		# Convert the space-separated MAJORS string into a jq array.
		# Example: "16 17 18" -> ["16", "17", "18"]
		($majors | split(" ")) as $majors

		# Keep only final releases:
		# exclude drafts and prereleases
		| map(select(.draft == false and .prerelease == false))

		# Normalize each release and keep only the requested major versions.
		| map(
			# Keep a reference to the original GitHub release object.
			. as $release

			# Remove an optional leading "v" from the tag.
			# Example: "v17.3.1" -> "17.3.1"
			| ($release.tag_name | sub("^v"; "")) as $version

			# Parse the version into numeric components so versions can be
			# compared numerically rather than lexicographically.
			# Example: "17.10.2" -> [17, 10, 2]
			| ($version | split(".") | map(tonumber)) as $version_parts

			# Extract the major version number as a string, matching the
			# representation used by MAJORS.
			# Example: "17.3.1" -> "17"
			| ($version_parts[0] | tostring) as $major

			# Ignore releases whose major version is not in MAJORS.
			| select($majors | index($major))

			# Reduce the GitHub release object to the fields needed below.
			| {
				major: $major,
				version: $version,
				assets: $release.assets
			}
		)

		# Process each selected release individually.
		| .[]

		# Save the release object because the next step switches the current
		# input (`.`) to one of its assets.
		| . as $release

		# Iterate over all assets attached to this GitHub release.
		| .assets[]

		# Keep only .tar.gz archives.
		| select(.name | test("\\.tar\\.gz$"))

		# Produce three output columns:
		#   1. release version
		#   2. asset download URL
		#   3. SHA-256 digest, with the "sha256:" prefix
		| [
			$release.version,
			.browser_download_url,
			.digest
		]

		# Render the array above as a tab-separated line.
		| @tsv
	'
