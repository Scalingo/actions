# Definition of Done Action

Checks the pull request description for a `Definition of Done` section. If that section is present, all checklist items must be checked.

## Inputs

- `pr-body` (required): pull request body markdown.
- `section-heading` (optional): heading text to match, default `Definition of Done`.

## Example

Reusable workflow example file: `examples/workflow.yml`.

```yaml
name: definition-of-done
on:
  pull_request:
    types: [opened, edited, synchronize, reopened, ready_for_review]

jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: Scalingo/actions/definition-of-done@main
        with:
          pr-body: ${{ github.event.pull_request.body }}
```

## Tests

Run:

```bash
./definition-of-done/tests/run.sh
```
