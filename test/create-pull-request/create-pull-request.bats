#!/usr/bin/env bats
#
# End-to-end tests for the vendored create-pull-request action.
#
# Driven by test/create-pull-request/run-e2e-test.sh, which sets:
#   CPR_REF   - branch, tag, or SHA of Scalingo/actions to test
#   CPR_OWNER - GitHub owner under which the disposable repo is created
#   CPR_KEEP  - "1" to keep the disposable repo after the run, "0" to delete it
#
# All state produced by setup_file is cached under $BATS_FILE_TMPDIR so it can
# be read back by individual @test blocks, which each run in their own process.

WORKFLOW_FILE="e2e-create-pull-request.yml"
BRANCH_NAME="e2e-test/create-pull-request"
TITLE="E2E test PR from create-pull-request action"
BODY="Automated PR created by the create-pull-request e2e test suite."
COMMIT_MESSAGE="test: automated change from e2e suite"
POLL_TIMEOUT_SECONDS=300
POLL_INTERVAL_SECONDS=5

_fixtures_dir() {
  cd "$(dirname "${BATS_TEST_FILENAME}")/fixtures" && pwd
}

# Renders the workflow template with the given payload/action ref and writes
# it to .github/workflows/$WORKFLOW_FILE in the current directory.
_render_workflow() {
  local action_ref="$1"
  local out=".github/workflows/$WORKFLOW_FILE"
  mkdir -p "$(dirname "$out")"
  sed \
    -e "s#__CPR_ACTION_REF__#Scalingo/actions/create-pull-request@${action_ref}#g" \
    -e "s#__CPR_COMMIT_MESSAGE__#${COMMIT_MESSAGE}#g" \
    -e "s#__CPR_TITLE__#${TITLE}#g" \
    -e "s#__CPR_BODY__#${BODY}#g" \
    -e "s#__CPR_BRANCH__#${BRANCH_NAME}#g" \
    "$(_fixtures_dir)/workflow.yml.tpl" > "$out"
}

# Dispatches the workflow with a unique payload, waits for the triggered run
# to complete, and echoes the run's database ID.
_dispatch_and_wait() {
  local repo_full="$1"
  local payload="$2"

  local before_ts
  before_ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  gh workflow run "$WORKFLOW_FILE" --repo "$repo_full" -f "payload=$payload" >&2

  local run_id=""
  local deadline=$((SECONDS + POLL_TIMEOUT_SECONDS))
  while [[ $SECONDS -lt $deadline ]]; do
    run_id="$(gh run list --repo "$repo_full" --workflow "$WORKFLOW_FILE" \
      --json databaseId,createdAt --jq \
      "[.[] | select(.createdAt >= \"$before_ts\")] | sort_by(.createdAt) | last | .databaseId // empty")"
    [[ -n "$run_id" ]] && break
    sleep "$POLL_INTERVAL_SECONDS"
  done

  if [[ -z "$run_id" ]]; then
    echo "error: workflow run was never triggered" >&2
    return 1
  fi

  gh run watch "$run_id" --repo "$repo_full" --exit-status >&2 || true

  echo "$run_id"
}

setup_file() {
  : "${CPR_REF:?CPR_REF must be set}"
  : "${CPR_OWNER:?CPR_OWNER must be set}"

  local repo_name
  repo_name="cpr-action-e2e-$(date +%s)-${RANDOM}"
  local repo_full="${CPR_OWNER}/${repo_name}"
  echo "$repo_full" > "$BATS_FILE_TMPDIR/repo_full"

  local work_dir="$BATS_FILE_TMPDIR/repo"
  mkdir -p "$work_dir"
  cd "$work_dir" || return 1

  git init -q -b main
  git config user.email "e2e-test@scalingo-actions.invalid"
  git config user.name "create-pull-request e2e test"

  echo "# create-pull-request action e2e test scratch repo" > README.md
  echo "Disposable repository, safe to delete." >> README.md
  _render_workflow "$CPR_REF"

  git add -A
  git commit -q -m "chore: initial commit"

  echo "Creating disposable repository $repo_full ..." >&2
  gh repo create "$repo_full" --private --source=. --remote=origin --push >&2

  # New repositories default to read-only workflow permissions and disallow
  # Actions from creating pull requests. The action needs both to work.
  gh api -X PUT "repos/$repo_full/actions/permissions/workflow" \
    -f default_workflow_permissions=write \
    -F can_approve_pull_request_reviews=true >&2

  # First run: creates the pull request.
  local first_payload
  first_payload="first-change-$(date +%s)"
  echo "$first_payload" > "$BATS_FILE_TMPDIR/first_payload"
  local first_run_id
  first_run_id="$(_dispatch_and_wait "$repo_full" "$first_payload")"
  echo "$first_run_id" > "$BATS_FILE_TMPDIR/first_run_id"
  gh run view "$first_run_id" --repo "$repo_full" --json conclusion -q .conclusion \
    > "$BATS_FILE_TMPDIR/first_run_conclusion"
  gh run view "$first_run_id" --repo "$repo_full" --log \
    > "$BATS_FILE_TMPDIR/first_run_log" || true

  gh pr list --repo "$repo_full" --state open \
    --json number,title,headRefName,body \
    > "$BATS_FILE_TMPDIR/pr_list_after_first_run.json"

  # Second run: pushes a different payload, action should update the same PR
  # rather than opening a new one.
  local second_payload
  second_payload="second-change-$(date +%s)"
  echo "$second_payload" > "$BATS_FILE_TMPDIR/second_payload"
  local second_run_id
  second_run_id="$(_dispatch_and_wait "$repo_full" "$second_payload")"
  echo "$second_run_id" > "$BATS_FILE_TMPDIR/second_run_id"
  gh run view "$second_run_id" --repo "$repo_full" --json conclusion -q .conclusion \
    > "$BATS_FILE_TMPDIR/second_run_conclusion"
  gh run view "$second_run_id" --repo "$repo_full" --log \
    > "$BATS_FILE_TMPDIR/second_run_log" || true

  gh pr list --repo "$repo_full" --state open \
    --json number,title,headRefName,body \
    > "$BATS_FILE_TMPDIR/pr_list_after_second_run.json"

  if [[ -n "$(jq -r '.[0].number // empty' "$BATS_FILE_TMPDIR/pr_list_after_second_run.json")" ]]; then
    local pr_number
    pr_number="$(jq -r '.[0].number' "$BATS_FILE_TMPDIR/pr_list_after_second_run.json")"
    gh pr diff "$pr_number" --repo "$repo_full" > "$BATS_FILE_TMPDIR/pr_diff.txt" || true
  fi
}

teardown_file() {
  local repo_full
  repo_full="$(cat "$BATS_FILE_TMPDIR/repo_full" 2>/dev/null || true)"
  if [[ -z "$repo_full" ]]; then
    return 0
  fi
  if [[ "${CPR_KEEP:-0}" == "1" ]]; then
    echo "Keeping disposable repository: https://github.com/$repo_full" >&2
    return 0
  fi

  echo "Deleting disposable repository $repo_full ..." >&2
  local delete_output
  if delete_output="$(gh repo delete "$repo_full" --yes 2>&1)"; then
    echo "Deleted disposable repository $repo_full." >&2
    return 0
  fi

  echo "############################################################" >&2
  echo "# WARNING: could not automatically delete the disposable   #" >&2
  echo "# test repository. Please delete it yourself.              #" >&2
  echo "############################################################" >&2
  echo "$delete_output" >&2
  if [[ "$delete_output" == *"delete_repo"* ]]; then
    echo "Reason: the gh token is missing the 'delete_repo' scope." >&2
    echo "Grant it with: gh auth refresh -h github.com -s delete_repo" >&2
    echo "Then delete the repository with:" >&2
  else
    echo "Delete the repository with:" >&2
  fi
  echo "  gh repo delete $repo_full --yes" >&2
  echo "Or manually at: https://github.com/$repo_full/settings" >&2
}

@test "first workflow run (creating the pull request) completes successfully" {
  run cat "$BATS_FILE_TMPDIR/first_run_conclusion"
  [ "$status" -eq 0 ]
  [ "$output" = "success" ]
}

@test "action creates exactly one open pull request" {
  run jq 'length' "$BATS_FILE_TMPDIR/pr_list_after_first_run.json"
  [ "$status" -eq 0 ]
  [ "$output" -eq 1 ]
}

@test "pull request has the expected title" {
  run jq -r '.[0].title' "$BATS_FILE_TMPDIR/pr_list_after_first_run.json"
  [ "$status" -eq 0 ]
  [ "$output" = "E2E test PR from create-pull-request action" ]
}

@test "pull request targets the expected branch name" {
  run jq -r '.[0].headRefName' "$BATS_FILE_TMPDIR/pr_list_after_first_run.json"
  [ "$status" -eq 0 ]
  [ "$output" = "e2e-test/create-pull-request" ]
}

@test "pull request body matches expected content" {
  run jq -r '.[0].body' "$BATS_FILE_TMPDIR/pr_list_after_first_run.json"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Automated PR created by the create-pull-request e2e test suite."* ]]
}

@test "action reports a pull-request-number output matching the real PR" {
  run jq -r '.[0].number' "$BATS_FILE_TMPDIR/pr_list_after_first_run.json"
  [ "$status" -eq 0 ]
  local expected_number="$output"
  run bash -c "grep -o 'pull-request-number=[0-9]*' '$BATS_FILE_TMPDIR/first_run_log' | sort -u"
  [ "$status" -eq 0 ]
  [ "$output" = "pull-request-number=$expected_number" ]
}

@test "second workflow run (updating the pull request) completes successfully" {
  run cat "$BATS_FILE_TMPDIR/second_run_conclusion"
  [ "$status" -eq 0 ]
  [ "$output" = "success" ]
}

@test "second run updates the existing pull request instead of creating a new one" {
  run jq 'length' "$BATS_FILE_TMPDIR/pr_list_after_second_run.json"
  [ "$status" -eq 0 ]
  [ "$output" -eq 1 ]

  run jq -r '.[0].number' "$BATS_FILE_TMPDIR/pr_list_after_first_run.json"
  local first_number="$output"
  run jq -r '.[0].number' "$BATS_FILE_TMPDIR/pr_list_after_second_run.json"
  [ "$output" = "$first_number" ]
}

@test "second run reports an 'updated' pull-request-operation output" {
  run bash -c "grep -o 'pull-request-operation=[a-z]*' '$BATS_FILE_TMPDIR/second_run_log' | sort -u"
  [ "$status" -eq 0 ]
  [ "$output" = "pull-request-operation=updated" ]
}

@test "the updated pull request diff contains the latest change" {
  [ -f "$BATS_FILE_TMPDIR/pr_diff.txt" ]
  run cat "$BATS_FILE_TMPDIR/second_payload"
  local second_payload="$output"
  run grep -F "$second_payload" "$BATS_FILE_TMPDIR/pr_diff.txt"
  [ "$status" -eq 0 ]
}
