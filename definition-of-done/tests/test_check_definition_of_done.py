#!/usr/bin/env python3

import importlib.util
import io
import os
import pathlib
import unittest
from contextlib import redirect_stdout
from unittest.mock import patch

SCRIPT_PATH = pathlib.Path(__file__).resolve().parents[1] / "scripts" / "check_definition_of_done.py"
SPEC = importlib.util.spec_from_file_location("check_definition_of_done", SCRIPT_PATH)
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC and SPEC.loader
SPEC.loader.exec_module(MODULE)


class DefinitionOfDoneTests(unittest.TestCase):
    def run_main(self, body: str, heading: str = "Definition of Done"):
        env = {
            "PR_BODY": body,
            "SECTION_HEADING": heading,
        }
        output = io.StringIO()
        with patch.dict(os.environ, env, clear=False), redirect_stdout(output):
            rc = MODULE.main()
        return rc, output.getvalue()

    def test_empty_body_fails(self):
        rc, output = self.run_main("   ")
        self.assertEqual(rc, 1)
        self.assertIn("PR description is empty", output)

    def test_missing_dod_heading_passes(self):
        rc, output = self.run_main("## Summary\nNo DoD section here")
        self.assertEqual(rc, 0)
        self.assertEqual(output, "")

    def test_checked_dod_passes(self):
        body = """## Definition of Done
- [x] Requirements understood
- [X] Tests updated
"""
        rc, output = self.run_main(body)
        self.assertEqual(rc, 0)
        self.assertEqual(output, "")

    def test_heading_matching_is_case_insensitive_and_spacing_tolerant(self):
        body = """### DeFiNiTiOn    Of   DoNe
- [x] item
"""
        rc, output = self.run_main(body)
        self.assertEqual(rc, 0)
        self.assertEqual(output, "")

    def test_unchecked_item_fails(self):
        body = """## Definition of Done
- [x] One
- [ ] Two
"""
        rc, output = self.run_main(body)
        self.assertEqual(rc, 1)
        self.assertIn("unchecked items", output)
        self.assertIn("Two", output)

    def test_dod_without_checklist_fails(self):
        body = """## Definition of Done
This section has no checklist
"""
        rc, output = self.run_main(body)
        self.assertEqual(rc, 1)
        self.assertIn("no checklist items", output)

    def test_custom_heading_can_be_used(self):
        body = """## Custom Done Block
- [x] All good
"""
        rc, output = self.run_main(body, heading="Custom Done Block")
        self.assertEqual(rc, 0)
        self.assertEqual(output, "")


if __name__ == "__main__":
    unittest.main()
