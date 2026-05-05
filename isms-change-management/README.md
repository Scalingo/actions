# ISMS Change Management Compliance Action

GitHub Action that validates changes to ISMS documents against the [ISMS Change Management Policy](https://github.com/Scalingo/specifications/blob/main/isms/Change-Management-Policy/ISMS-Change-Management-Policy-Fr.md).

It checks that:

1. **Author ≠ Validator** — no one can validate their own change
2. **Version is bumped** — the document version must be strictly increased
3. **Double validation** — minor or major version bumps require at least 2 validators
4. **RSSI role** *(optional)* — the RSSI must be a validator, with a specific exception when the RSSI is the author

## Usage

```yaml
jobs:
  isms-compliance:
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Check ISMS change management compliance
        uses: Scalingo/actions/isms-change-management@main
        with:
          base-ref: main
          rssi: "Yannick Jost"
          cto: "Léo Unbekandt"
          ceo: "Frédéric Harper"
```

## Inputs

| Input           | Required | Default        | Description |
|-----------------|----------|----------------|-------------|
| `base-ref`      | no       | merge-base with `origin/main` | Base branch ref to compare against (e.g. `main`) |
| `files-pattern` | no       | `isms/**/*.md` | Glob pattern selecting which markdown files are ISMS documents |
| `rssi`          | no       | `""` | Comma-separated full name(s) of the RSSI holder(s). When set, enables the RSSI role check. |
| `cto`           | no       | `""` | Comma-separated full name(s) of the CTO(s). Used when `rssi` is set. |
| `ceo`           | no       | `""` | Comma-separated full name(s) of the CEO(s). Used when `rssi` is set. |

> `fetch-depth: 0` is required in the `actions/checkout` step so that git history is available for the base-ref comparison.

## Validation Checks

The action reads the YAML front matter of each changed ISMS document. The expected front matter shape is:

```yaml
---
version: 1.2.0
authors:
  - Alice Martin
validators:
  - Bob Dupont
---
```

### 1. Author ≠ Validator

The person who authors a change cannot also validate it. This enforces the separation of duties required by the ISMS Change Management Policy.

**Triggers an error when** any name appears in both the `authors` list and the `validators` list of the same document.

```yaml
# ❌ Error: Alice authored and validated the same change
authors:
  - Alice Martin
validators:
  - Alice Martin
  - Bob Dupont
```

### 2. Version Bump Required

Every approved ISMS change must produce a new version of the document. The version uses [semver](https://semver.org/) (`MAJOR.MINOR.PATCH`).

**Triggers an error when** the `version` field in the changed document is equal to or lower than the version on the base branch.

```yaml
# Base branch: version: 1.1.0
# ❌ Error: version unchanged
version: 1.1.0

# ✅ OK: version increased
version: 1.1.1
```

New documents (not present on the base branch) are exempt from this check.

### 3. Double Validation for Minor and Major Bumps

The policy requires two validators for changes that materially affect the content of a document:

- **Minor bump** (`x.Y.z` increments): an article or step was added or removed
- **Major bump** (`X.y.z` increments): more than 50% of the content was rewritten

A **patch bump** (`x.y.Z` increments, cosmetic corrections) only requires 1 validator.

**Triggers an error when** a minor or major bump has fewer than 2 validators.

```yaml
# Base: version: 1.0.0 → new: 1.1.0 (minor bump)
# ❌ Error: only 1 validator for a minor bump
validators:
  - Bob Dupont

# ✅ OK: 2 validators
validators:
  - Bob Dupont
  - Carol Lefèvre
```

### 4. RSSI Role Check *(enabled when `rssi` input is set)*

All ISMS documents must be validated by the RSSI. However, the RSSI cannot validate their own changes. When the RSSI is the author, the CTO or CEO must validate instead.

**Triggers an error when:**
- The RSSI is **not** the author **and** is **not** among the validators, or
- The RSSI **is** the author and neither the CTO nor the CEO is among the validators.

```yaml
# RSSI = "Yannick Jost", CTO = "Léo Unbekandt"

# ✅ Normal case: RSSI validates
authors:
  - Alice Martin
validators:
  - Yannick Jost

# ✅ Exception: RSSI is author, CTO validates
authors:
  - Yannick Jost
validators:
  - Léo Unbekandt

# ❌ Error: RSSI is not author and not validator
authors:
  - Alice Martin
validators:
  - Bob Dupont
```
