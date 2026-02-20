# PR Validation Actions for Compliance (WIP)

Status: **Work in progress**  
Goal: Add GitHub Actions checks to enforce PR metadata and description compliance before merge.

## Objectives
- Validate PR **title** and **description** against organization compliance rules.
- Enforce a **Definition of Done** (DoD) checklist when present.
- Fail the check on **errors** only (warnings are allowed and should not block merging).
- Minimize dependencies: use GitHub-maintained actions and simple scripting; avoid “shady” third-party actions.

## Inputs / Sources of Truth
- PR template (user-facing): `.github/pull_request_template.md`
- Compliance policy (machine-readable rubric, can be markdown): `.github/pr_compliance_policy.md`
- PR data from event payload:
  - `pull_request.title`
  - `pull_request.body`

## Compliance Rules (current)
### Ticket references
Acceptable ticket reference formats:
- Jira key: `ABCDEF-12345`
  - Pattern: `[A-Z]{2,10}-[0-9]{1,6}`
- GitHub issue/PR references (including other repos):
  - URL: `https://github.com/<owner>/<repo>/issues/<number>`
  - URL: `https://github.com/<owner>/<repo>/pull/<number>`
  - Cross-repo shorthand: `<owner>/<repo>#<number>`
  - Same-repo shorthand: `#<number>` (optional; decide whether to accept)

### PR title (mandatory, error)
- MUST contain either:
  - a ticket reference (Jira key or GitHub issue/PR reference), OR
  - an explicit “no ticket” explanation, e.g.:
    - `[no-ticket: <reason>]`
    - `(no ticket - <reason>)`
    - `No ticket: <reason>`
- If “no ticket”, the reason must be explanatory (not just “N/A”).

### PR description structure (mandatory, error)
- Must include all required section headings defined in `.github/pull_request_template.md`.
- Where a section contains instructions, those instructions must be followed.

### N/A handling
- `N/A` is allowed.
- When used, it must include an explanation of **at least one sentence** (e.g., `N/A - <one sentence explanation>`).

### Prohibited placeholders (error)
- Disallow placeholder tokens such as: `TBD`, `TODO`, `??` (case-insensitive).

## Definition of Done (DoD) Checklist Enforcement (mandatory when present)
Requirement:
- If a DoD section is present in the PR description, **all checklist items under it must be checked**.

Detection:
- Accept **any Markdown heading level** (`#` through `######`) with text matching
  - `definition of done` (case-insensitive; allow arbitrary capitalization)
- The DoD section content runs until the next Markdown heading of any level or end-of-document.
- Checklist items are Markdown task list items:
  - checked: `- [x] ...`
  - unchecked: `- [ ] ...`

Failure conditions:
- DoD heading exists but contains **no** checklist items => **error**
- Any unchecked DoD checklist item => **error**

## Implementation Notes (current approach)
- Deterministic checks (no AI):
  - DoD checklist fully checked if present
  - Block placeholder tokens
  - (Optionally) regex-based ticket-in-title check
- LLM-based checks (OpenAI):
  - Evaluate title/body against policy + template for “follow instructions” and completeness
  - Enforce “errors fail, warnings do not”
  - Require strict JSON output from the model (machine-parsable)

## Workflow Expectations
- Trigger on: PR opened/edited/synchronize/reopened/ready_for_review
- Result: a required status check that blocks merge when failing
- Output: clear error messages in workflow logs (and optionally PR comment in later iteration)

## Open Questions / Next Decisions
- Should same-repo shorthand `#123` be accepted as a ticket reference?
- Should ticket references in the PR body be allowed to satisfy the title rule, or title-only?
- Should multiple DoD sections be supported (enforce all) or just the first occurrence?