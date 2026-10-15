# Update Buildpack Inventory

A composite GitHub Action that adds new releases to a buildpack inventory and
creates or updates a pull request with the changes.

The action reads GitHub releases from the repository specified by `repository`,
ignores releases marked as drafts or prereleases by GitHub, and selects
releases for the requested major or major.minor version series.

Prerelease filtering uses GitHub's release flags, not the tag name. A tag such
as `11.0.0-preview` is included if it matches the requested series and GitHub
does not mark the release as a draft or prerelease.

The required `download_url` template allows to build archive URLs from release
versions. The action also downloads archives to calculate SHA-256 checksums.

The inventory keeps the newest entry only for each base version
(`major.minor.patch`). For example, if `13.0.1`, `13.0.1+security-01`, and
`13.0.1+security-02` are available, only `13.0.1+security-02` is kept. Version
`13.0.2` has a different base version, so it is kept as a separate entry.

The full version string is preserved in the inventory. Revisions are ordered
using GNU version sort, and superseded entries are removed before applying
release limits.

When `releases_limit` is set, only the newest N releases per requested series
are kept, including existing entries. Without a limit, all matching releases
are kept. Entries outside the requested series are removed. Overlapping
selectors do not duplicate entries.

The inventory is sorted by version, newest first, and the newest entry in the
selected default series is marked `default`. If that default series has no
inventory entry, no entry is marked as default.

Changes are proposed through the `feat/inventory/auto_update` branch with the
pull request title `chore(inventory): auto-update inventory`. An existing pull
request is updated; no new pull request is created when there are no changes.


## Available Inputs

- `repository` (req):\
  Repository to read releases from, in `owner/repo` format, for example
  `keycloak/keycloak`.\
  Must be nonempty.

- `download_url` (req):\
  Archive URL template, for example
  `"https://downloads.example.com/{version}/software-{version}-linux-amd64.tar.gz"`.\
  Every `{version}` is replaced with the full release version, including any
  suffix and without the leading `v`. Replacement is literal, without URL
  encoding.\
  Only new versions retained after filtering and release limits are downloaded.
  Their checksums are stored as `sha256:<hex digest>`. If a download fails,
  the row is retained with `FIXME` in the Checksum column for manual
  correction. Existing URLs and checksums, including `FIXME`, are preserved on
  later runs.\
  Must be nonempty.

- `version_series` (req):\
  Major or major.minor versions to consider, separated by whitespace.\
  Controls which releases are kept and which series `releases_limit` applies
  to.\
  For example: `"16 17 18"` or `"13.2 13.1 13.0 12.4"`.\
  An optional `.x` suffix is accepted, so `13.2.x` is equivalent to `13.2`.\
  A selector of `13` includes all `13.x` releases; `13.1` includes only
  `13.1.x`, not `13.10.x`.\
  Must be nonempty.

- `default_series` (opt):\
  Major or major.minor selector whose newest inventory entry becomes the
  default.\
  If omitted or absent from `version_series`, defaults to the highest requested
  series.

- `releases_limit` (opt):\
  Maximum number of releases to retain per requested version series, newest
  first. Must be a positive integer, for example `"3"`.\
  If omitted, all releases are kept.

- `inventory_file` (opt):\
  Path to the inventory file, relative to the repository root.\
  The inventory file is created if it doesn't exist.\
  Existing nonempty files must be Tab-Separated Values (TSV) files with a header row and four columns
  in this order: `Version`, `URL`, `Checksum`, `Default?`. The first row is
  always treated as the header and replaced when the inventory is updated.\
  Defaults to `INVENTORY.tsv`.

- `pr_assignees` (opt):\
  Comma or newline-separated list of GitHub usernames to assign to the pull
  request.\
  If omitted, no assignees are specified.

- `pr_reviewers` (opt):\
  Comma or newline-separated list of GitHub usernames to request a pull request
  review from.\
  If omitted, no reviewers are specified.


## Example

```yaml
name: Update buildpack inventory

on:
  workflow_dispatch:
  schedule:
    # Everyday at 6am:
    - cron: "0 6 * * *"

jobs:
  update-inventory:
    runs-on: ubuntu-26.04
    permissions:
      contents: write
      pull-requests: write
    steps:
      - name: Update inventory
        uses: Scalingo/actions/update-buildpack-inventory@main
        env:
          GH_TOKEN: ${{ github.token }}
        with:
          inventory_file: INVENTORY.tsv
          repository: keycloak/keycloak
          download_url: "https://github.com/keycloak/keycloak/releases/download/{version}/keycloak-{version}.tar.gz"
          version_series: "25 26"
          default_series: "26"
          releases_limit: 3
          pr_assignees: "${{ vars.AUTO_ASSIGNEES }}"
          pr_reviewers: "${{ vars.AUTO_REVIEWERS }}"
```
