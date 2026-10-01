# Update Buildpack Inventory

A composite GitHub Action that adds new releases to a buildpack inventory and
creates or updates a pull request with the changes.

The action reads GitHub releases from the repository specified by `repository`,
ignores drafts and prereleases, and selects releases for the requested major
versions. It uses `.tar.gz` release assets to populate the inventory with the
version, download URL, and digest supplied by GitHub.

The inventory is updated in the repository running the workflow, where the
pull request is also created. The release source can be a different repository.

Existing versions are kept without updating their URL or checksum. The inventory
is sorted by version, newest first, and the newest entry in the selected default
major is marked `default`. If that major has no inventory entry, no entry is
marked as default.

Changes are proposed through the `feat/inventory/auto_update` branch with the
pull request title `(auto) update inventory`. An existing pull request is updated;
no new pull request is created when there are no changes.

## Available Inputs

- `repository` (req):\
  Repository to read releases from, in `owner/repo` format, for example
  `keycloak/keycloak`.\
  Must be nonempty.

- `inventory_file` (opt):\
  Path to the existing inventory file, relative to `GITHUB_WORKSPACE`.\
  Defaults to `INVENTORY.tsv`.

- `major_versions` (req):\
  Major versions to consider, separated by single spaces, for example
  `"16 17 18"`.\
  It only controls which releases are added. It does not remove existing
  entries from other major versions.\
  Must be nonempty.

- `default_major` (opt):\
  Major whose newest inventory entry becomes the default.\
  If omitted or absent from `major_versions`, defaults to the highest requested
  major.

- `pr_assignees` (opt):\
  Comma or newline-separated list of GitHub usernames to assign to the pull
  request.\
  If omitted, no assignees are specified.

- `pr_reviewers` (opt):\
  Comma or newline-separated list of GitHub usernames to request a pull request
  review from.\
  If omitted, no reviewers are specified.


## Instructions

- Use a Linux runner with Bash, GNU command-line utilities, Git, GitHub CLI (`gh`),
  and `jq` available.

- Release tags must contain numeric, dot-separated versions, optionally
  prefixed with `v`, such as `17.3.1` or `v17.3.1`. Releases should provide a
  `.tar.gz` asset with a SHA-256 digest. The action copies the digest; it does
  not download and hash the archive. Only one inventory entry is kept per
  version; if a release has multiple matching assets, the first encountered is
  used.

- Set `GH_TOKEN` for [GitHub CLI authentication](https://cli.github.com/manual/gh_auth_login).
  The example below uses the workflow's token to read releases from a public
  repository. For a private release source, provide a token with access to it.

- Declare `permissions` in the calling workflow, either at the workflow level
  or on the job using this action.\
  Grant the calling workflow `contents: write` and `pull-requests: write`, and
  enable **Allow GitHub Actions to create and approve pull requests** in the
  repository's [Actions settings](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/enabling-features-for-your-repository/managing-github-actions-settings-for-a-repository).


## Example

Save this workflow as `.github/workflows/update-inventory.yml` in the repository
containing the inventory. This example reads releases from `keycloak/keycloak`:

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
          repository: keycloak/keycloak
          inventory_file: INVENTORY.tsv
          major_versions: "25 26"
          default_major: "26"
          pr_assignees: "${{ vars.AUTO_ASSIGNEES }}"
          pr_reviewers: "${{ vars.AUTO_REVIEWERS }}"
```
