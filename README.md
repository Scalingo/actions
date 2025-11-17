# Actions

This repository contains all the GitHub actions of the Scalingo organisation. Each action must be in a `action.yml` file located in a folder. The file name is a GitHub constraint.

## Go Continuous Integration

### How To Use These Actions in a Private Repository

See how it's used in the [go-project-template](https://github.com/Scalingo/go-project-template/blob/master/.github/workflows/ci.yml).

### How To Use These Actions in a Public Repository

In order to use one of these actions in a public repository, one must first clone this repository. Then it can be used like a local composite action.

Add the GitHub token in your GitHub Action secrets. In the repository: "Settings" -> "Secrets and variables" -> "Actions" -> "New repository secret". Name it `TOKEN`. This token must have the permissions to read the GitHub Action repository.

```yml
jobs:
  linter:
    name: Linter on a PR
    if: ${{ github.event_name == 'pull_request' }}
    runs-on: ubuntu-24.04
    steps:
      # Checkout the current repository
      - uses: actions/checkout@v5
        with:
          # We need to define the fetch-depth to 0 so that we can get the commit ID of the master branch
          fetch-depth: 0

      # Checkout the GitHub Action
      - uses: actions/checkout@v5
        with:
          repository: Scalingo/actions
          ref: main
          path: github-actions
          token: ${{ secrets.TOKEN }}

      - uses: ./github-actions/go-linter
```
