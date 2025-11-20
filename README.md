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

## Automatically Merge Dependabot Pull Requests

GitHub action to automatically merge the Dependabot PRs. It merges the dependency upgrade if it upgrades a minor or patch version.

See how it's used in the [go-project-template](https://github.com/Scalingo/go-project-template/blob/master/.github/workflows/dependabot.yml).
