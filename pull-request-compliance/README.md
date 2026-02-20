# Pull Request Compliance Action

Validates pull request title/body with deterministic checks and optional OpenAI policy/template validation.

## Deterministic checks

- Empty PR description is rejected.
- `Definition of Done` checklist must be fully checked when the section is present.
- Placeholder tokens `TBD`, `TODO`, and `??` are rejected.

## Inputs

- `pr-title` (required): pull request title.
- `pr-body` (required): pull request body markdown.
- `template-path` (optional): default `.github/pull_request_template.md`.
- `policy-path` (optional): default `.github/pr_compliance_policy.md`.
- `openai-api-key` (optional): enables policy/template LLM validation when set.
- `openai-model` (optional): default `gpt-4o-mini`.

## Example

Reusable workflow example file: `examples/workflow.yml`.

```yaml
name: pr-compliance
on:
  pull_request:
    types: [opened, edited, synchronize, reopened, ready_for_review]

jobs:
  check:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: read
    steps:
      - uses: actions/checkout@v4

      - uses: Scalingo/actions/pull-request-compliance@main
        with:
          pr-title: ${{ github.event.pull_request.title }}
          pr-body: ${{ github.event.pull_request.body }}
          openai-api-key: ${{ secrets.OPENAI_API_KEY }}
```

## Tests

Run:

```bash
./pull-request-compliance/tests/run.sh
```

Unit tests mock OpenAI calls, so no API key is required.
