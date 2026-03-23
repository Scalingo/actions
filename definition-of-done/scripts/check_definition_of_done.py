#!/usr/bin/env python3
"""Validate Definition of Done checklist sections in Markdown text."""

import os
import re
import sys


def heading_pattern(heading_text: str) -> str:
    tokens = heading_text.strip().split()
    if not tokens:
        return r"definition\s+of\s+done"
    return r"\s+".join(re.escape(token) for token in tokens)


def find_dod_sections(body: str, heading_text: str) -> list[str]:
    title_pattern = heading_pattern(heading_text)
    heading_re = re.compile(rf"(?im)^#{{1,6}}\s*{title_pattern}\s*$")
    generic_heading_re = re.compile(r"(?im)^#{1,6}\s+\S.*$")

    sections: list[str] = []
    for match in heading_re.finditer(body):
        start = match.end()
        next_heading = generic_heading_re.search(body, pos=start)
        end = next_heading.start() if next_heading else len(body)
        sections.append(body[start:end])

    return sections


def validate_section(section: str) -> list[str]:
    items = re.findall(r"(?m)^\s*-\s*\[(?P<mark>[ xX])\]\s+(?P<text>.+?)\s*$", section)
    if not items:
        return ["A 'Definition of Done' heading is present, but no checklist items were found under it."]

    unchecked = [text for mark, text in items if mark.strip() == ""]
    if not unchecked:
        return []

    errors = ["Definition of Done checklist has unchecked items:"]
    errors.extend(f" - {item}" for item in unchecked)
    return errors


def main() -> int:
    body = os.environ.get("PR_BODY", "")
    heading = os.environ.get("SECTION_HEADING", "Definition of Done")

    if not body.strip():
        print("::error::PR description is empty.")
        return 1

    sections = find_dod_sections(body, heading)
    if not sections:
        return 0

    for section in sections:
        errors = validate_section(section)
        if errors:
            for error in errors:
                print(f"::error::{error}")
            return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())
