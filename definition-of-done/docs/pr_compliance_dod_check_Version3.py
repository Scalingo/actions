import re, sys

def enforce_definition_of_done(body: str) -> None:
    """
    If a Markdown heading (any level) matches 'definition of done' (case-insensitive),
    require all task list items under that section to be checked.

    Section runs until the next Markdown heading of any level or end of text.
    """
    # Match headings like:
    # # Definition of Done
    # ## definition of done
    # ###### DeFiNiTiOn Of DoNe
    heading_re = re.compile(
        r"(?im)^(?P<hashes>#{1,6})\s*(?P<title>definition\s+of\s+done)\s*$"
    )

    m = heading_re.search(body)
    if not m:
        return  # DoD section not present => no enforcement

    start = m.end()

    # Find next heading after this one (any level)
    next_heading_re = re.compile(r"(?im)^#{1,6}\s+\S.*$")
    m2 = next_heading_re.search(body, pos=start)
    section = body[start:] if not m2 else body[start:m2.start()]

    # Task list items in Markdown
    items = re.findall(
        r"(?m)^\s*-\s*\[(?P<mark>[ xX])\]\s+(?P<text>.+?)\s*$",
        section
    )
    if not items:
        print("::error::A 'Definition of Done' heading is present, but no checklist items were found under it.")
        sys.exit(1)

    unchecked = [text for mark, text in items if mark.strip() == ""]
    if unchecked:
        print("::error::Definition of Done checklist has unchecked items:")
        for t in unchecked:
            print(f" - {t}")
        sys.exit(1)