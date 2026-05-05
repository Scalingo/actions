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
