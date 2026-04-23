# -----------------------------
# Deterministic: DoD checklist
# -----------------------------
import re, sys

heading_re = re.compile(r"(?im)^#{1,6}\s*definition\s+of\s+done\s*$")
m = heading_re.search(body)
if m:
    start = m.end()
    next_heading_re = re.compile(r"(?im)^#{1,6}\s+\S.*$")
    m2 = next_heading_re.search(body, pos=start)
    section = body[start:] if not m2 else body[start:m2.start()]

    items = re.findall(r"(?m)^\s*-\s*\[(?P<mark>[ xX])\]\s+(?P<text>.+?)\s*$", section)
    if not items:
        print("::error::A 'Definition of Done' heading is present, but no checklist items were found under it.")
        sys.exit(1)

    unchecked = [text for mark, text in items if mark.strip() == ""]
    if unchecked:
        print("::error::Definition of Done checklist has unchecked items:")
        for t in unchecked:
            print(f" - {t}")
        sys.exit(1)