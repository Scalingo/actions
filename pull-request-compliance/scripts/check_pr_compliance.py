#!/usr/bin/env python3
"""Validate pull-request title/body against deterministic and policy-based checks."""

import json
import os
import re
import sys
import urllib.error
import urllib.request


def heading_pattern(heading_text: str) -> str:
    tokens = heading_text.strip().split()
    if not tokens:
        return r"definition\s+of\s+done"
    return r"\s+".join(re.escape(token) for token in tokens)


def validate_definition_of_done(body: str, heading_text: str = "Definition of Done") -> list[str]:
    title_pattern = heading_pattern(heading_text)
    heading_re = re.compile(rf"(?im)^#{{1,6}}\s*{title_pattern}\s*$")
    generic_heading_re = re.compile(r"(?im)^#{1,6}\s+\S.*$")

    errors: list[str] = []
    matches = list(heading_re.finditer(body))
    for match in matches:
        start = match.end()
        next_heading = generic_heading_re.search(body, pos=start)
        end = next_heading.start() if next_heading else len(body)
        section = body[start:end]

        items = re.findall(r"(?m)^\s*-\s*\[(?P<mark>[ xX])\]\s+(?P<text>.+?)\s*$", section)
        if not items:
            errors.append("A 'Definition of Done' heading is present, but no checklist items were found under it.")
            continue

        unchecked = [text for mark, text in items if mark.strip() == ""]
        if unchecked:
            errors.append("Definition of Done checklist has unchecked items:")
            errors.extend(f" - {item}" for item in unchecked)

    return errors


def validate_placeholders(body: str) -> list[str]:
    errors: list[str] = []
    for token in ("TBD", "TODO"):
        if re.search(rf"\b{re.escape(token)}\b", body, flags=re.IGNORECASE):
            errors.append(f"Forbidden placeholder '{token}' found in PR description.")
    if "??" in body:
        errors.append("Forbidden placeholder '??' found in PR description.")
    return errors


def read_file(path: str) -> str:
    try:
        with open(path, "r", encoding="utf-8") as file_obj:
            return file_obj.read()
    except OSError as exc:
        print(f"::error::Cannot read {path}: {exc}")
        sys.exit(1)


def call_openai(model: str, api_key: str, prompt: str) -> dict:
    payload = {
        "model": model,
        "response_format": {"type": "json_object"},
        "messages": [
            {"role": "system", "content": "Return only JSON. No extra text."},
            {"role": "user", "content": prompt},
        ],
        "temperature": 0,
    }

    request = urllib.request.Request(
        "https://api.openai.com/v1/chat/completions",
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        },
        method="POST",
    )

    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            body = response.read().decode("utf-8")
    except urllib.error.HTTPError as exc:
        details = exc.read().decode("utf-8", errors="replace")
        print(f"::error::OpenAI request failed with HTTP {exc.code}: {details}")
        sys.exit(1)
    except Exception as exc:  # noqa: BLE001
        print(f"::error::OpenAI request failed: {exc}")
        sys.exit(1)

    try:
        data = json.loads(body)
        content = data["choices"][0]["message"]["content"]
        return json.loads(content)
    except Exception as exc:  # noqa: BLE001
        print(f"::error::Model output parsing failed: {exc}")
        print(body)
        sys.exit(1)


def main() -> int:
    title = os.environ.get("PR_TITLE", "")
    body = os.environ.get("PR_BODY", "")
    template_path = os.environ.get("TEMPLATE_PATH", ".github/pull_request_template.md")
    policy_path = os.environ.get("POLICY_PATH", ".github/pr_compliance_policy.md")
    openai_key = os.environ.get("OPENAI_API_KEY", "")
    model = os.environ.get("OPENAI_MODEL", "gpt-4o-mini")

    if not body.strip():
        print("::error::PR description is empty.")
        return 1

    template = read_file(template_path)
    policy = read_file(policy_path)

    deterministic_errors = []
    deterministic_errors.extend(validate_definition_of_done(body))
    deterministic_errors.extend(validate_placeholders(body))

    if deterministic_errors:
        for error in deterministic_errors:
            print(f"::error::{error}")
        return 1

    if not openai_key:
        print("::warning::OPENAI_API_KEY is not configured. Skipping policy/template LLM validation.")
        return 0

    prompt = f"""
You are a strict compliance checker for pull requests.

Evaluate the PR TITLE and PR DESCRIPTION against:
1. The PR template (required sections and intent)
2. The PR compliance policy (source of truth)

Template:
---
{template}
---

Policy:
---
{policy}
---

PR title:
---
{title}
---

PR description:
---
{body}
---

Rules:
- N/A is allowed only when accompanied by at least one sentence of explanation.
- If policy and template conflict, policy wins.
- Be conservative: unclear or missing details are violations.
- Return JSON only with this schema:
{{
  "pass": boolean,
  "violations": [
    {{
      "id": string,
      "severity": "error" | "warning",
      "location": "title" | "description",
      "message": string,
      "suggested_fix": string
    }}
  ]
}}
"""

    result = call_openai(model, openai_key, prompt)

    passed = bool(result.get("pass", False))
    violations = result.get("violations", [])
    error_violations = [entry for entry in violations if entry.get("severity") == "error"]

    print("Compliance result:")
    print(json.dumps(result, indent=2))

    if (not passed) or error_violations:
        print("::error::PR failed compliance checks.")
        for violation in violations:
            severity = violation.get("severity", "error")
            location = violation.get("location", "description")
            message = violation.get("message", "")
            fix = violation.get("suggested_fix", "")
            print(f"- [{severity}] ({location}) {message}")
            if fix:
                print(f"  suggested_fix: {fix}")
        return 1

    for violation in violations:
        if violation.get("severity") == "warning":
            location = violation.get("location", "description")
            message = violation.get("message", "")
            print(f"::warning::({location}) {message}")

    print("PR passed compliance checks.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
