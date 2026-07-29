# Vendoring notice

This directory is a vendored copy of the
[`peter-evans/create-pull-request`](https://github.com/peter-evans/create-pull-request)
GitHub Action.

## Why

We vendor the source of this third-party action into this repository instead
of referencing `peter-evans/create-pull-request` directly in our workflows.
This removes the supply-chain risk of depending on an external, unpinned-by-us
action: the upstream maintainer's account, npm dependencies, or release
pipeline could be compromised and silently affect every workflow that uses it
across the Scalingo organisation. Vendoring lets us review, pin, and audit the
exact code that runs, the same way we already do for other third-party
dependencies. Tracked in SITM-2436.

Once vendored, use it in workflows as `Scalingo/actions/create-pull-request@main`
instead of `peter-evans/create-pull-request@vX`.

## Source

- Upstream repository: https://github.com/peter-evans/create-pull-request
- Vendored tag: [`v8.1.1`](https://github.com/peter-evans/create-pull-request/releases/tag/v8.1.1)
- Vendored commit: [`5f6978faf089d4d20b00c7766989d076bb2fc7f1`](https://github.com/peter-evans/create-pull-request/commit/5f6978faf089d4d20b00c7766989d076bb2fc7f1)

The upstream `LICENSE` (MIT) is kept as-is alongside the vendored source.
Repository-management files that are specific to the upstream project
(its own `.github/` workflows, dependabot config, funding file, issue
template) were removed since they don't apply once vendored here.

## Updating

To pull in a newer upstream version:

1. Clone `peter-evans/create-pull-request` at the desired tag.
2. Copy `action.yml`, `dist/`, `docs/`, `src/`, `__test__/`, `LICENSE`,
   `README.md` and the other project files over this directory, excluding
   upstream's `.github/` directory and any other upstream repo-management
   files.
3. Update the "Vendored tag" and "Vendored commit" references above.
4. Review the diff before opening a pull request, paying attention to
   `dist/index.js` since it is the compiled code actually executed.
