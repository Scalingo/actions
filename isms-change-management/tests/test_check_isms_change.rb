#!/usr/bin/env ruby
# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require "fileutils"

SCRIPT_PATH = File.expand_path("../scripts/check_isms_change.rb", __dir__)
load SCRIPT_PATH

# ---------------------------------------------------------------------------
# Helper to build a minimal markdown document with YAML front matter
# ---------------------------------------------------------------------------
def make_doc(version:, authors:, validators:)
  authors_yaml    = authors.map { |a| "    - #{a}" }.join("\n")
  validators_yaml = validators.map { |v| "    - #{v}" }.join("\n")

  <<~MD
    ---
    title: Test Document
    version: #{version}
    authors:
    #{authors_yaml}
    validators:
    #{validators_yaml.empty? ? "    []" : validators_yaml}
    ---

    # Test Document
  MD
end

# ---------------------------------------------------------------------------
# Unit tests for individual check functions
# ---------------------------------------------------------------------------

class TestAuthorValidatorCoherence < Minitest::Test
  def test_no_overlap_passes
    fm = { "authors" => ["Alice"], "validators" => ["Bob"] }
    assert_empty check_author_validator_coherence("file.md", fm)
  end

  def test_overlap_fails
    fm = { "authors" => ["Alice", "Bob"], "validators" => ["Bob", "Carol"] }
    errors = check_author_validator_coherence("file.md", fm)
    refute_empty errors
    assert_match(/Bob/, errors.first)
  end

  def test_multiple_overlaps_reported_individually
    fm = { "authors" => ["Alice", "Bob"], "validators" => ["Alice", "Bob"] }
    errors = check_author_validator_coherence("file.md", fm)
    assert_equal 2, errors.size
  end

  def test_empty_validators_passes
    fm = { "authors" => ["Alice"], "validators" => [] }
    assert_empty check_author_validator_coherence("file.md", fm)
  end
end

class TestVersionBump < Minitest::Test
  def test_bumped_version_passes
    old_fm = { "version" => "1.0.0" }
    new_fm = { "version" => "1.0.1" }
    assert_empty check_version_bump("file.md", old_fm, new_fm)
  end

  def test_same_version_fails
    old_fm = { "version" => "1.0.0" }
    new_fm = { "version" => "1.0.0" }
    errors = check_version_bump("file.md", old_fm, new_fm)
    refute_empty errors
    assert_match(/not greater/, errors.first)
  end

  def test_decremented_version_fails
    old_fm = { "version" => "1.2.0" }
    new_fm = { "version" => "1.1.0" }
    errors = check_version_bump("file.md", old_fm, new_fm)
    refute_empty errors
  end

  def test_major_bump_passes
    old_fm = { "version" => "1.9.9" }
    new_fm = { "version" => "2.0.0" }
    assert_empty check_version_bump("file.md", old_fm, new_fm)
  end

  def test_no_old_version_skips_check
    old_fm = { "version" => "" }
    new_fm = { "version" => "1.0.0" }
    assert_empty check_version_bump("file.md", old_fm, new_fm)
  end
end

class TestDoubleValidation < Minitest::Test
  def test_patch_bump_one_validator_passes
    old_fm = { "version" => "1.0.0" }
    new_fm = { "version" => "1.0.1", "validators" => ["Alice"] }
    assert_empty check_double_validation("file.md", old_fm, new_fm)
  end

  def test_minor_bump_one_validator_fails
    old_fm = { "version" => "1.0.0" }
    new_fm = { "version" => "1.1.0", "validators" => ["Alice"] }
    errors = check_double_validation("file.md", old_fm, new_fm)
    refute_empty errors
    assert_match(/minor/, errors.first)
    assert_match(/2 validators/, errors.first)
  end

  def test_minor_bump_two_validators_passes
    old_fm = { "version" => "1.0.0" }
    new_fm = { "version" => "1.1.0", "validators" => ["Alice", "Bob"] }
    assert_empty check_double_validation("file.md", old_fm, new_fm)
  end

  def test_major_bump_one_validator_fails
    old_fm = { "version" => "1.0.0" }
    new_fm = { "version" => "2.0.0", "validators" => ["Alice"] }
    errors = check_double_validation("file.md", old_fm, new_fm)
    refute_empty errors
    assert_match(/major/, errors.first)
  end

  def test_major_bump_two_validators_passes
    old_fm = { "version" => "1.0.0" }
    new_fm = { "version" => "2.0.0", "validators" => ["Alice", "Bob"] }
    assert_empty check_double_validation("file.md", old_fm, new_fm)
  end
end

class TestRssiRole < Minitest::Test
  RSSI = ["Yannick Jost"].freeze
  CTO  = ["Léo Unbekandt"].freeze
  CEO  = ["Jean Dupont"].freeze

  def test_rssi_is_validator_passes
    fm = { "authors" => ["Alice"], "validators" => ["Yannick Jost"] }
    assert_empty check_rssi_role("file.md", fm, RSSI, CTO, CEO)
  end

  def test_rssi_not_validator_and_not_author_fails
    fm = { "authors" => ["Alice"], "validators" => ["Bob"] }
    errors = check_rssi_role("file.md", fm, RSSI, CTO, CEO)
    refute_empty errors
    assert_match(/RSSI/, errors.first)
  end

  def test_rssi_is_author_cto_validates_passes
    fm = { "authors" => ["Yannick Jost"], "validators" => ["Léo Unbekandt"] }
    assert_empty check_rssi_role("file.md", fm, RSSI, CTO, CEO)
  end

  def test_rssi_is_author_ceo_validates_passes
    fm = { "authors" => ["Yannick Jost"], "validators" => ["Jean Dupont"] }
    assert_empty check_rssi_role("file.md", fm, RSSI, CTO, CEO)
  end

  def test_rssi_is_author_no_cto_or_ceo_fails
    fm = { "authors" => ["Yannick Jost"], "validators" => ["Alice"] }
    errors = check_rssi_role("file.md", fm, RSSI, CTO, CEO)
    refute_empty errors
    assert_match(/CTO or CEO/, errors.first)
  end

  def test_no_rssi_configured_skips_check
    fm = { "authors" => ["Alice"], "validators" => ["Bob"] }
    assert_empty check_rssi_role("file.md", fm, [], CTO, CEO)
  end
end

class TestSemverCompare < Minitest::Test
  def test_patch_greater
    assert_equal 1, semver_compare("1.0.1", "1.0.0")
  end

  def test_minor_greater
    assert_equal 1, semver_compare("1.1.0", "1.0.9")
  end

  def test_major_greater
    assert_equal 1, semver_compare("2.0.0", "1.9.9")
  end

  def test_equal
    assert_equal 0, semver_compare("1.2.3", "1.2.3")
  end

  def test_lesser
    assert_equal(-1, semver_compare("1.0.0", "1.0.1"))
  end

  def test_prerelease_less_than_release
    assert_equal(-1, semver_compare("1.0.0-beta1", "1.0.0"))
  end
end

class TestParseFrontMatter < Minitest::Test
  def test_valid_front_matter
    content = "---\ntitle: Test\nversion: 1.0.0\n---\n# Body"
    fm = parse_front_matter(content)
    assert_equal "Test", fm["title"]
    assert_equal "1.0.0", fm["version"]
  end

  def test_no_front_matter_returns_nil
    assert_nil parse_front_matter("# Just a heading\nNo front matter.")
  end

  def test_unclosed_front_matter_returns_nil
    assert_nil parse_front_matter("---\ntitle: Test\n")
  end
end

class TestNormalizeName < Minitest::Test
  def test_case_insensitive_match
    assert name_in_list?("Yannick Jost", ["yannick jost"])
    assert name_in_list?("YANNICK JOST", ["Yannick Jost"])
  end

  def test_extra_whitespace_normalized
    assert name_in_list?("Yannick  Jost", ["Yannick Jost"])
    assert name_in_list?("Yannick Jost", ["Yannick  Jost"])
  end

  def test_no_match
    refute name_in_list?("Alice Martin", ["Bob Dupont", "Carol Lefèvre"])
  end
end

class TestCommitAuthorsCoherence < Minitest::Test
  def test_all_authors_listed_passes
    fm = { "authors" => ["Alice Martin", "Bob Dupont"] }
    assert_empty check_commit_authors_coherence("file.md", fm, ["Alice Martin"])
  end

  def test_unlisted_commit_author_fails
    fm = { "authors" => ["Alice Martin"] }
    errors = check_commit_authors_coherence("file.md", fm, ["Alice Martin", "Bob Dupont"])
    refute_empty errors
    assert_match(/Bob Dupont/, errors.first)
  end

  def test_name_matching_is_case_insensitive
    fm = { "authors" => ["alice martin"] }
    assert_empty check_commit_authors_coherence("file.md", fm, ["Alice Martin"])
  end

  def test_empty_commit_authors_skips_check
    fm = { "authors" => ["Alice Martin"] }
    assert_empty check_commit_authors_coherence("file.md", fm, [])
  end

  def test_multiple_unlisted_authors_reported
    fm = { "authors" => ["Alice Martin"] }
    errors = check_commit_authors_coherence("file.md", fm, ["Bob Dupont", "Carol Lefèvre"])
    assert_equal 2, errors.size
  end
end

class TestValidatorsAreApprovers < Minitest::Test
  def test_validators_match_approvers_passes
    fm = { "validators" => ["Bob Dupont"] }
    assert_empty check_validators_are_approvers("file.md", fm, ["Bob Dupont"])
  end

  def test_nil_approved_reviewers_skips_check
    fm = { "validators" => ["Bob Dupont"] }
    assert_empty check_validators_are_approvers("file.md", fm, nil)
  end

  def test_yaml_validator_not_in_approvers_fails
    fm = { "validators" => ["Bob Dupont"] }
    errors = check_validators_are_approvers("file.md", fm, ["Carol Lefèvre"])
    assert errors.any? { |e| e.include?("Bob Dupont") && e.include?("not approved") }
  end

  def test_approver_not_in_yaml_validators_fails
    fm = { "validators" => ["Bob Dupont"] }
    errors = check_validators_are_approvers("file.md", fm, ["Bob Dupont", "Carol Lefèvre"])
    assert errors.any? { |e| e.include?("Carol Lefèvre") && e.include?("not listed as a validator") }
  end

  def test_bidirectional_mismatch_reports_both
    fm = { "validators" => ["Bob Dupont"] }
    errors = check_validators_are_approvers("file.md", fm, ["Carol Lefèvre"])
    assert_equal 2, errors.size
  end

  def test_name_matching_is_case_insensitive
    fm = { "validators" => ["bob dupont"] }
    assert_empty check_validators_are_approvers("file.md", fm, ["Bob Dupont"])
  end

  def test_empty_validators_and_approvers_passes
    fm = { "validators" => [] }
    assert_empty check_validators_are_approvers("file.md", fm, [])
  end
end

# ---------------------------------------------------------------------------
# Helpers shared by content-change tests
# ---------------------------------------------------------------------------

def make_body(headings: ["Introduction", "Policy"], lines: [])
  heading_lines = headings.map { |h| "## #{h}" }
  ([heading_lines] + [lines]).flatten.join("\n") + "\n"
end

def wrap_doc(body, version: "1.0.0", authors: ["Alice"], validators: ["Bob"])
  front = "---\nversion: #{version}\nauthors:\n  - #{authors.join("\n  - ")}\nvalidators:\n  - #{validators.join("\n  - ")}\n---\n"
  front + body
end

class TestStripFrontMatter < Minitest::Test
  def test_strips_front_matter
    content = "---\nversion: 1.0.0\n---\n# Body\nSome text."
    assert_equal "# Body\nSome text.", strip_front_matter(content)
  end

  def test_no_front_matter_returns_content_unchanged
    content = "# Just a heading\nNo front matter."
    assert_equal content, strip_front_matter(content)
  end

  def test_unclosed_front_matter_returns_content_unchanged
    content = "---\nversion: 1.0.0\n"
    assert_equal content, strip_front_matter(content)
  end
end

class TestExtractHeadings < Minitest::Test
  def test_extracts_headings
    content = "---\nv: 1\n---\n## Intro\nSome text.\n### Sub\nMore."
    assert_equal ["## Intro", "### Sub"], extract_headings(content)
  end

  def test_ignores_front_matter_lines
    content = "---\ntitle: My Doc\n---\n## Real Heading"
    assert_equal ["## Real Heading"], extract_headings(content)
  end

  def test_no_headings_returns_empty
    content = "---\nv: 1\n---\nJust a paragraph."
    assert_empty extract_headings(content)
  end
end

class TestClassifyContentChange < Minitest::Test
  SAME_BODY = make_body(headings: ["Intro", "Policy"], lines: Array.new(20) { |i| "Line #{i + 1}." })

  def old_doc
    wrap_doc(SAME_BODY)
  end

  def test_identical_body_is_patch
    assert_equal :patch, classify_content_change(old_doc, old_doc)
  end

  def test_cosmetic_wording_is_patch
    new_body = SAME_BODY.sub("Line 1.", "Line one.")
    assert_equal :patch, classify_content_change(old_doc, wrap_doc(new_body))
  end

  def test_heading_added_is_minor
    new_body = SAME_BODY + "## New Section\nSome content.\n"
    assert_equal :minor, classify_content_change(old_doc, wrap_doc(new_body))
  end

  def test_heading_removed_is_minor
    new_body = SAME_BODY.lines.reject { |l| l.include?("## Policy") }.join
    assert_equal :minor, classify_content_change(old_doc, wrap_doc(new_body))
  end

  def test_major_rewrite_is_major
    # Replace more than 50 % of body lines with entirely new content
    old_lines = Array.new(20) { |i| "Old line #{i + 1}.\n" }
    new_lines = Array.new(20) { |i| "New line #{i + 1}.\n" }
    old_body = "## Intro\n" + old_lines.join
    new_body = "## Intro\n" + old_lines.first(3).join + new_lines.drop(3).join
    assert_equal :major, classify_content_change(wrap_doc(old_body), wrap_doc(new_body))
  end

  def test_only_front_matter_changed_is_patch
    new_doc = wrap_doc(SAME_BODY, version: "1.0.1")
    assert_equal :patch, classify_content_change(old_doc, new_doc)
  end
end

class TestVersionMatchesContentChange < Minitest::Test
  def test_patch_content_with_patch_bump_passes
    old_fm = { "version" => "1.0.0" }
    new_fm = { "version" => "1.0.1" }
    assert_empty check_version_matches_content_change("file.md", old_fm, new_fm, :patch)
  end

  def test_patch_content_with_minor_bump_passes
    old_fm = { "version" => "1.0.0" }
    new_fm = { "version" => "1.1.0" }
    assert_empty check_version_matches_content_change("file.md", old_fm, new_fm, :patch)
  end

  def test_minor_content_with_patch_bump_fails
    old_fm = { "version" => "1.0.0" }
    new_fm = { "version" => "1.0.1" }
    errors = check_version_matches_content_change("file.md", old_fm, new_fm, :minor)
    refute_empty errors
    assert_match(/minor/, errors.first)
    assert_match(/patch/, errors.first)
  end

  def test_minor_content_with_minor_bump_passes
    old_fm = { "version" => "1.0.0" }
    new_fm = { "version" => "1.1.0" }
    assert_empty check_version_matches_content_change("file.md", old_fm, new_fm, :minor)
  end

  def test_minor_content_with_major_bump_passes
    old_fm = { "version" => "1.0.0" }
    new_fm = { "version" => "2.0.0" }
    assert_empty check_version_matches_content_change("file.md", old_fm, new_fm, :minor)
  end

  def test_major_content_with_minor_bump_fails
    old_fm = { "version" => "1.0.0" }
    new_fm = { "version" => "1.1.0" }
    errors = check_version_matches_content_change("file.md", old_fm, new_fm, :major)
    refute_empty errors
    assert_match(/major/, errors.first)
    assert_match(/minor/, errors.first)
  end

  def test_major_content_with_major_bump_passes
    old_fm = { "version" => "1.0.0" }
    new_fm = { "version" => "2.0.0" }
    assert_empty check_version_matches_content_change("file.md", old_fm, new_fm, :major)
  end
end

class TestBuildPrComment < Minitest::Test
  def all_passed_result
    {
      file:         "isms/policy.md",
      passed:       true,
      actual_bump:  :patch,
      old_version:  "1.0.0",
      new_version:  "1.0.1",
      content_kind: :patch,
      checks: [
        { name: "Author ≠ Validator",            passed: true,  errors: [] },
        { name: "Version bumped",                 passed: true,  errors: [] },
        { name: "Version matches content change", passed: true,  errors: [] }
      ]
    }
  end

  def test_overall_pass_message
    comment = build_pr_comment([all_passed_result])
    assert_match(/All checks passed/, comment)
    refute_match(/Some checks failed/, comment)
  end

  def test_overall_fail_message
    result = all_passed_result.merge(
      passed: false,
      checks: [{ name: "Version bumped", passed: false, errors: ["Version not bumped."] }]
    )
    comment = build_pr_comment([result])
    assert_match(/Some checks failed/, comment)
  end

  def test_check_mark_for_passing_check
    comment = build_pr_comment([all_passed_result])
    assert_match(/✅ Author ≠ Validator/, comment)
  end

  def test_cross_mark_for_failing_check
    result = all_passed_result.merge(
      passed: false,
      checks: [{ name: "Version bumped", passed: false, errors: ["Not bumped."] }]
    )
    comment = build_pr_comment([result])
    assert_match(/❌.*Version bumped.*Not bumped\./, comment)
  end

  def test_includes_bump_and_content_info_in_heading
    comment = build_pr_comment([all_passed_result])
    assert_match(/patch bump \(1\.0\.0 → 1\.0\.1\)/, comment)
    assert_match(/content change: \*\*patch\*\*/, comment)
  end

  def test_comment_starts_with_marker
    comment = build_pr_comment([all_passed_result])
    assert comment.start_with?(COMMENT_MARKER)
  end
end
