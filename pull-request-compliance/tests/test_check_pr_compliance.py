#!/usr/bin/env python3

import importlib.util
import io
import os
import pathlib
import tempfile
import unittest
from contextlib import redirect_stdout
from unittest.mock import patch

SCRIPT_PATH = pathlib.Path(__file__).resolve().parents[1] / "scripts" / "check_pr_compliance.py"
SPEC = importlib.util.spec_from_file_location("check_pr_compliance", SCRIPT_PATH)
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC and SPEC.loader
SPEC.loader.exec_module(MODULE)


class PullRequestComplianceTests(unittest.TestCase):
    def run_main(
        self,
        body: str,
        title: str = "Test title",
        api_key: str = "",
        openai_result: dict | None = None,
    ):
        with tempfile.TemporaryDirectory() as tempdir:
            template_path = pathlib.Path(tempdir) / "template.md"
            policy_path = pathlib.Path(tempdir) / "policy.md"
            template_path.write_text("## Summary\n## Ticket\n", encoding="utf-8")
            policy_path.write_text("Policy content", encoding="utf-8")

            env = {
                "PR_TITLE": title,
                "PR_BODY": body,
                "TEMPLATE_PATH": str(template_path),
                "POLICY_PATH": str(policy_path),
                "OPENAI_API_KEY": api_key,
                "OPENAI_MODEL": "gpt-4o-mini",
            }

            output = io.StringIO()
            with patch.dict(os.environ, env, clear=False), redirect_stdout(output):
                if openai_result is None:
                    rc = MODULE.main()
                else:
                    with patch.object(MODULE, "call_openai", return_value=openai_result) as mocked:
                        rc = MODULE.main()
                        self.assertEqual(mocked.call_count, 1)

            return rc, output.getvalue()

    def test_empty_body_fails(self):
        rc, output = self.run_main("   ")
        self.assertEqual(rc, 1)
        self.assertIn("PR description is empty", output)

    def test_dod_unchecked_item_fails(self):
        body = """## Definition of Done
- [x] Good
- [ ] Missing
"""
        rc, output = self.run_main(body)
        self.assertEqual(rc, 1)
        self.assertIn("unchecked items", output)

    def test_placeholders_fail(self):
        rc, output = self.run_main("## Summary\nTODO later\n")
        self.assertEqual(rc, 1)
        self.assertIn("Forbidden placeholder 'TODO'", output)

        rc, output = self.run_main("## Summary\nNeed clarification ??\n")
        self.assertEqual(rc, 1)
        self.assertIn("Forbidden placeholder '??'", output)

    def test_no_api_key_skips_llm_and_passes_when_deterministic_checks_pass(self):
        body = """## Summary
Looks good.

## Definition of Done
- [x] Requirement understood
"""
        rc, output = self.run_main(body, api_key="")
        self.assertEqual(rc, 0)
        self.assertIn("Skipping policy/template LLM validation", output)

    def test_llm_error_violation_fails(self):
        body = "## Summary\nLooks good\n"
        llm_result = {
            "pass": False,
            "violations": [
                {
                    "id": "missing-ticket",
                    "severity": "error",
                    "location": "description",
                    "message": "Ticket reference missing",
                    "suggested_fix": "Add a ticket link",
                }
            ],
        }
        rc, output = self.run_main(body, api_key="test-key", openai_result=llm_result)
        self.assertEqual(rc, 1)
        self.assertIn("PR failed compliance checks", output)
        self.assertIn("Ticket reference missing", output)

    def test_llm_warning_only_passes(self):
        body = "## Summary\nLooks good\n"
        llm_result = {
            "pass": True,
            "violations": [
                {
                    "id": "clarity",
                    "severity": "warning",
                    "location": "description",
                    "message": "Could add more detail",
                    "suggested_fix": "Explain rollout",
                }
            ],
        }
        rc, output = self.run_main(body, api_key="test-key", openai_result=llm_result)
        self.assertEqual(rc, 0)
        self.assertIn("PR passed compliance checks", output)
        self.assertIn("Could add more detail", output)


if __name__ == "__main__":
    unittest.main()
