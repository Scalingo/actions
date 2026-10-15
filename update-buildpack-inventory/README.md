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

The base version is the numeric `major.minor.patch` prefix; suffixes such as
`-preview`, `+security-02`, and `.revision-2` all belong to that same base.

Only the newest revision of each base version is kept: `13.0.1+security-02`
replaces `13.0.1+security-01` and `13.0.1`, while `13.0.2` remains a separate
entry.

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
pull request title `chore(inventory) auto-update inventory`. An existing pull
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
  Path to the inventory file, relative to `GITHUB_WORKSPACE`.\
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


## Instructions

- `scripts/get_latest_releases.sh` reads `REPOSITORY` and `SERIES` and prints
  one version per line. `scripts/update_buildpack_inventory.sh` reads those
  versions from stdin, builds URLs from `DOWNLOAD_URL`, calculates checksums,
  and writes the four-column inventory.

- Use a Linux runner with Bash, GNU command-line utilities, Git, GitHub CLI
  (`gh`), `jq`, `curl`, and `sha256sum` available. Downloads follow redirects
  and have a ten-minute timeout.

- Release tags must start with numeric `major.minor.patch`, optionally
  prefixed with `v` and followed by any suffix, such as
  `17.3.1`, `v11.0.0-preview`, or `13.0.1+security-02`.
  Tags without this numeric prefix are ignored. Only the numeric base is used
  to match `version_series`.

- GitHub supplies versions only. The archive bytes are streamed through
  `sha256sum`; no archive is retained on disk. HTTP errors, connection
  failures, and incomplete downloads produce a `FIXME` rather than a checksum
  of an error response or partial archive.

- Set `GH_TOKEN` for [GitHub CLI authentication](https://cli.github.com/manual/gh_auth_login).
  The example below uses the workflow's token to read releases from a public
  repository. For a private release source, provide a token with access to it.

- Declare `permissions` in the calling workflow, either at the workflow level
  or on the job using this action.\
  Grant the calling workflow `contents: write` and `pull-requests: write`, and
  enable **Allow GitHub Actions to create and approve pull requests** in the
  repository's [Actions settings](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/enabling-features-for-your-repository/managing-github-actions-settings-for-a-repository).


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
