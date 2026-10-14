#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

gh api "repos/${REPOSITORY}/releases" --paginate \
	| jq --raw-output --arg series "${SERIES}" '
		#
		# Accept major or major.minor selectors, optionally ending in .x.
		# Match numeric components, so 13.1 never matches 13.10.
		($series | [scan("\\S+") | sub("\\.x$"; "")
			| split(".") | map(tonumber)]) as $series

		# Keep only final releases:
		# exclude drafts and prereleases
		| map(select(.draft == false and .prerelease == false))

		# Normalize each release and keep only the requested version series.
		| map(
			# Keep a reference to the original GitHub release object.
			. as $release

			# Remove an optional leading "v" from the tag.
			# Example: "v17.3.1" -> "17.3.1"
			| ($release.tag_name | sub("^v"; "")) as $version

			# Match using the numeric base, keeping the full version for output.
			# Extract major.minor.patch regardless of the suffix separator.
			# Example: "11.0.0-preview" -> [11, 0, 0]
			# Tags without a numeric major.minor.patch prefix are ignored.
			| ($version | match("^[0-9]+\\.[0-9]+\\.[0-9]+")
				| .string | split(".") | map(tonumber)) as $version_parts

			# Keep releases matching any requested version prefix.
			| select(any($series[]; . as $prefix
				| $version_parts[:($prefix | length)] == $prefix))

			| $version
		)

		# Emit one full version per line for the inventory updater.
		| .[]
	'
