#!/usr/bin/env ruby
# frozen_string_literal: true

# Validates ISMS document changes against the ISMS Change Management Policy.
#
# Checks performed for each changed ISMS markdown file:
#   1. Author ≠ Validator  — no person may appear in both authors and validators
#   2. Version bump        — version must be strictly greater than on the base branch
#   3. Double validation   — minor or major bumps require at least 2 validators
#   4. RSSI role           — RSSI must be a validator (unless RSSI is the author,
#                            in which case CTO or CEO must validate)
#
# Environment variables:
#   BASE_REF        — base branch ref (optional; falls back to merge-base with origin/main)
#   FILES_PATTERN   — glob pattern for ISMS documents (default: isms/**/*.md)
#   RSSI            — comma-separated name(s) of the RSSI holder(s)
#   CTO             — comma-separated name(s) of the CTO(s)
#   CEO             — comma-separated name(s) of the CEO(s)

require "yaml"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def split_names(env_value)
  (env_value || "").split(",").map(&:strip).reject(&:empty?)
end

# Parse the YAML front matter block from a markdown string.
# Returns a Hash, or nil when no front matter is present.
def parse_front_matter(content)
  return nil unless content.start_with?("---")

  end_index = content.index("\n---", 3)
  return nil unless end_index

  yaml_block = content[3...end_index]
  YAML.safe_load(yaml_block, permitted_classes: [])
rescue Psych::Exception
  nil
end

# Compare two semver strings.
# Returns -1, 0, or 1 (similar to <=>).
# Pre-release labels (e.g. "1.0.0-beta1") sort before the release version.
def semver_compare(ver_a, ver_b)
  parse = lambda do |v|
    match = v.to_s.match(/\A(\d+)\.(\d+)\.(\d+)(?:-(.+))?\z/)
    return [0, 0, 0, ""] unless match

    [match[1].to_i, match[2].to_i, match[3].to_i, match[4] || ""]
  end

  a = parse.call(ver_a)
  b = parse.call(ver_b)

  # Compare numeric parts first
  (0..2).each do |i|
    return a[i] <=> b[i] unless a[i] == b[i]
  end

  # Pre-release label: no label (release) > any label (pre-release)
  return 0 if a[3] == b[3]
  return 1 if a[3].empty?   # a is release, b is pre-release → a > b
  return -1 if b[3].empty?  # b is release, a is pre-release → a < b

  a[3] <=> b[3]
end

# Determine the kind of version bump: :major, :minor, :patch, or :none.
def bump_kind(old_ver, new_ver)
  parse = lambda do |v|
    m = v.to_s.match(/\A(\d+)\.(\d+)\.(\d+)/)
    m ? [m[1].to_i, m[2].to_i, m[3].to_i] : [0, 0, 0]
  end

  old = parse.call(old_ver)
  new_v = parse.call(new_ver)

  return :major if new_v[0] > old[0]
  return :minor if new_v[1] > old[1]
  return :patch if new_v[2] > old[2]

  :none
end

# Emit a GitHub Actions error annotation.
def error(file, message)
  puts "::error file=#{file}::#{message}"
end

# ---------------------------------------------------------------------------
# Validation checks
# ---------------------------------------------------------------------------

# Check 1: authors and validators must be disjoint.
def check_author_validator_coherence(file, front_matter)
  authors    = Array(front_matter["authors"]).map(&:to_s)
  validators = Array(front_matter["validators"]).map(&:to_s)

  overlap = authors & validators
  return [] if overlap.empty?

  overlap.map do |name|
    "#{name} appears in both authors and validators. The author of a change cannot also validate it."
  end
end

# Check 2: version must be strictly greater than the base version.
def check_version_bump(file, old_front_matter, new_front_matter)
  old_version = old_front_matter["version"].to_s
  new_version = new_front_matter["version"].to_s

  return [] if old_version.empty?

  if semver_compare(new_version, old_version) <= 0
    return ["Version #{new_version} is not greater than the base version #{old_version}. " \
            "Every approved change must produce a new, higher version number."]
  end

  []
end

# Check 3: minor or major bumps require at least 2 validators.
def check_double_validation(file, old_front_matter, new_front_matter)
  old_version = old_front_matter["version"].to_s
  new_version = new_front_matter["version"].to_s
  validators  = Array(new_front_matter["validators"]).map(&:to_s).reject(&:empty?)

  kind = bump_kind(old_version, new_version)
  return [] unless %i[minor major].include?(kind)
  return [] if validators.size >= 2

  ["A #{kind} version bump (#{old_version} → #{new_version}) requires at least 2 validators, " \
   "but only #{validators.size} found: #{validators.join(", ").then { |s| s.empty? ? "(none)" : s }}"]
end

# Check 4: RSSI must validate, unless RSSI is the author (then CTO or CEO must validate).
# Only runs when rssi_names is non-empty.
def check_rssi_role(file, front_matter, rssi_names, cto_names, ceo_names)
  return [] if rssi_names.empty?

  authors    = Array(front_matter["authors"]).map(&:to_s)
  validators = Array(front_matter["validators"]).map(&:to_s)

  rssi_is_author    = (rssi_names & authors).any?
  rssi_is_validator = (rssi_names & validators).any?

  if rssi_is_author
    # RSSI authored the change → CTO or CEO must validate instead
    fallback_present = ((cto_names + ceo_names) & validators).any?
    unless fallback_present
      return ["The RSSI is the author of this change. In this case, the CTO or CEO must be a validator, " \
              "but neither was found among validators: #{validators.join(", ").then { |s| s.empty? ? "(none)" : s }}"]
    end
  else
    # Normal case: RSSI must be a validator
    unless rssi_is_validator
      return ["All ISMS documents must be validated by the RSSI (#{rssi_names.join(", ")}), " \
              "but the RSSI was not found among validators: #{validators.join(", ").then { |s| s.empty? ? "(none)" : s }}"]
    end
  end

  []
end

# ---------------------------------------------------------------------------
# File discovery
# ---------------------------------------------------------------------------

def resolve_base_ref
  base_ref = ENV.fetch("BASE_REF", "").strip
  return base_ref unless base_ref.empty?

  # Fall back to the merge-base with origin/main
  result = `git merge-base HEAD origin/main 2>/dev/null`.strip
  result.empty? ? "origin/main" : result
end

def changed_files(base_ref)
  `git diff --name-only "#{base_ref}" HEAD 2>/dev/null`.split("\n").map(&:strip).reject(&:empty?)
end

def file_exists_in_base?(file, base_ref)
  system("git cat-file -e \"#{base_ref}:#{file}\" 2>/dev/null")
end

def read_base_content(file, base_ref)
  `git show "#{base_ref}:#{file}" 2>/dev/null`
end

def matches_pattern?(file, pattern)
  File.fnmatch(pattern, file, File::FNM_PATHNAME)
end

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main
  base_ref       = resolve_base_ref
  files_pattern  = ENV.fetch("FILES_PATTERN", "isms/**/*.md").strip
  rssi_names     = split_names(ENV["RSSI"])
  cto_names      = split_names(ENV["CTO"])
  ceo_names      = split_names(ENV["CEO"])

  all_changed = changed_files(base_ref)
  isms_files  = all_changed.select { |f| f.end_with?(".md") && matches_pattern?(f, files_pattern) }

  if isms_files.empty?
    puts "No ISMS documents changed — nothing to check."
    return 0
  end

  puts "Checking #{isms_files.size} changed ISMS document(s) against base #{base_ref}..."

  all_errors = []

  isms_files.each do |file|
    new_content = File.read(file, encoding: "utf-8") rescue nil
    unless new_content
      error(file, "Cannot read file #{file}")
      all_errors << file
      next
    end

    new_fm = parse_front_matter(new_content)
    unless new_fm
      # Not an ISMS document with front matter — skip silently
      next
    end

    file_errors = []

    # Check 1 always applies
    file_errors += check_author_validator_coherence(file, new_fm)

    if file_exists_in_base?(file, base_ref)
      base_content = read_base_content(file, base_ref)
      old_fm = parse_front_matter(base_content)

      if old_fm
        # Check 2: version bump
        file_errors += check_version_bump(file, old_fm, new_fm)

        # Check 3: double validation for minor/major
        file_errors += check_double_validation(file, old_fm, new_fm)
      end
    else
      puts "::notice file=#{file}::New document — version and double-validation checks skipped."
    end

    # Check 4: RSSI role (optional)
    file_errors += check_rssi_role(file, new_fm, rssi_names, cto_names, ceo_names)

    file_errors.each { |msg| error(file, msg) }
    all_errors.concat(file_errors)
  end

  if all_errors.empty?
    puts "All ISMS change management checks passed."
    0
  else
    1
  end
end

exit(main) if __FILE__ == $PROGRAM_NAME
