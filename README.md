# Actions

This repository contains all the GitHub actions of the Scalingo organisation. Each action must be in a `action.yml` file located in a folder. The file name is a GitHub constraint.

## Go Continuous Integration

See how it's used in the [go-project-template](https://github.com/Scalingo/go-project-template/blob/master/.github/workflows/ci.yml).

The linter and tests GitHub actions have different options that can be enabled if needed:
- Linter:
  - `sqlc`: install sqlc and execute `sqlc diff` to detect if a call to `sqlc generate` is missing. The default value is `auto`. With this value the action tries to automatically detect if sqlc is configured on the project and it is worth executing the `diff` command. Other possible options are `true` and `false`.
- Tests:
  - `mongodb`: run a MongoDB database so that unit tests can use it. An environment variable `MONGO_URL` is set in the unit tests execution environment with the connection string. The default value is `auto`. With this value the action tries to automatically detect if MongoDB is configured on the project. Other possible options are `true` and `false`.
  - `etcd`: run a etcd single-node cluster reachable on `127.0.0.1:2379`. The default value is `false`. Other possible value is `true` to run etcd.
  - `redis`: run a Redis database reachable on `127.0.0.1:6379`. The default value is `false`. Other possible value is `true` to run Redis.

Enable one of this option with:

```yml
jobs:
  linter:
    # ...
    steps:
      - uses: Scalingo/actions/go-linter@main
        with:
          - <option_name>: true
```

The calling repository can customize the unit tests environment by adding a script `bin/scalingo-ci-extra-setup.sh` that is executed before the unit tests execution.

## Ruby Continuous Integration

The Ruby checks and specs GitHub actions have different options that can be enabled if needed:
- Checks:
  - `rubocop`: execute RuboCop linter. The default value is `auto`. With this value the action tries to automatically detect if RuboCop is available in the bundle. Other possible options are `true` and `false`.
  - `brakeman`: execute Brakeman security scanner. The default value is `auto`. With this value the action tries to automatically detect if Brakeman is available in the bundle. Other possible options are `true` and `false`.
  - `zeitwerk`: execute Zeitwerk loader check. The default value is `auto`. With this value the action tries to automatically detect if the `zeitwerk:check` rake task exists. Other possible options are `true` and `false`.
- Specs:
  - `mongodb`: run a MongoDB database so that specs can use it. An environment variable is set in the specs execution environment with the connection string. The default value is `auto`. With this value the action tries to automatically detect if MongoDB is configured on the project (by checking for the `mongoid` gem in `Gemfile`). Other possible options are `true` and `false`.
  - `redis`: run a Redis database reachable on `127.0.0.1:6379`. The default value is `auto`. With this value the action tries to automatically detect if Redis is configured on the project (by checking for the `redis` gem in `Gemfile`). Other possible options are `true` and `false`.
  - `pact`: execute Pact verification after the specs if needed. The default value is `auto`. With this value the action tries to automatically detect if Pact is configured on the project (by checking for the `pact:verify` rake task in the Rakefile). Other possible options are `true` and `false`.
  - `github_token`: GitHub token for API access. It is used to upload code coverage status. If not set, the action doesn't upload code coverage status on github. Note: the [permission `statuses: write` must be granted to the GitHub token](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#defining-access-for-the-github_token-scopes-1) used in order to report coverage status.

Enable one of these options with:

```yml
jobs:
  checks:
    # ...
    steps:
      - uses: Scalingo/actions/ruby-checks@main
        with:
          - <option_name>: true | false
```

```yml
jobs:
  specs:
    # ...
    steps:
      - uses: Scalingo/actions/ruby-specs@main
        with:
          - <option_name>: true | false
```
## Go release process

Two actions are present to release services which are go binaries:

- [go-stable-release](/go-stable-release): Create a tag based on the name of the branch: `release/vX.Y.Z` which got merged and create a stable Release using GoReleaser
- [go-rolling-release](/go-rolling-release): Create a tag based on the name of the latest stable tag then create a prerelease Github Release using GoReleaser

Example of usage is presents in the `actions.yml` of each action

## Automatically Merge Dependabot Pull Requests

GitHub action to automatically merge the Dependabot PRs. It merges the dependency upgrade if it upgrades a minor or patch version.

See how it's used in the [go-project-template](https://github.com/Scalingo/go-project-template/blob/master/.github/workflows/dependabot.yml).

## Import GPG key into the local agent

GitHub Action to import a GPG key into the local agent, primarily used for signing Terraform provider releases.

## ShellCheck

The ShellCheck Github action allows to run ShellCheck on a repository.

Available inputs:

- `shellcheck-version` (opt):\
  Allows to specify the version of ShellCheck to use.\
  Must be a valid [Docker Hub release tag](https://hub.docker.com/r/koalaman/shellcheck/tags).\
  Defaults to `v0.11.0`

- `shellcheck-severity` (opt):\
  Allows to specify the minimum severity of errors to consider.\
  Valid values in order of severity are: `error`, `warning`, `info` and
  `style`.\
  Defaults to `style`.

- `files` (opt):\
  Allows to specify the path to the files to scan.\
  Paths must be given relative to the repository root directory.\
  They must be seperated by a newline.\
  Spaces are preserved.\
  Defaults to all `.sh` files in the repository, except those in the `.git`
  directory.

Here is an example:

```yaml
jobs:
  shellcheck:
    name: "ShellCheck"
    runs-on: ubuntu-latest
    steps:
      - uses: Scalingo/actions/shellcheck@main
        with:
          shellcheck-severity: style
          files: |
            first_file.sh
            second file.sh
            third
```
