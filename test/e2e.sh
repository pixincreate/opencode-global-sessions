#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

DB="$TMPDIR/opencode.db"
SESSION_ID="ses_test1234567890"
NOW_MS=$(( $(date +%s) * 1000 ))

sqlite3 "$DB" <<SQL
CREATE TABLE project (
  id TEXT PRIMARY KEY,
  name TEXT
);
CREATE TABLE session (
  id TEXT PRIMARY KEY,
  project_id TEXT,
  directory TEXT,
  title TEXT,
  time_created INTEGER,
  time_updated INTEGER,
  agent TEXT,
  model TEXT,
  version TEXT,
  cost REAL,
  tokens_input INTEGER,
  tokens_output INTEGER,
  tokens_reasoning INTEGER,
  tokens_cache_read INTEGER,
  tokens_cache_write INTEGER
);
CREATE TABLE message (
  id TEXT PRIMARY KEY,
  session_id TEXT NOT NULL,
  time_created INTEGER NOT NULL,
  time_updated INTEGER NOT NULL,
  data TEXT NOT NULL
);
CREATE TABLE part (
  id TEXT PRIMARY KEY,
  message_id TEXT NOT NULL,
  session_id TEXT NOT NULL,
  time_created INTEGER NOT NULL,
  time_updated INTEGER NOT NULL,
  data TEXT NOT NULL
);

INSERT INTO project VALUES ('proj_test', 'test-project');
INSERT INTO session VALUES (
  '$SESSION_ID',
  'proj_test',
  '/tmp/sesh-test-project',
  'Test session with justfile',
  $NOW_MS,
  $NOW_MS,
  'test-agent',
  '{"id":"test-model","providerID":"test-provider"}',
  'test-version',
  0,
  10,
  20,
  0,
  0,
  0
);
INSERT INTO message VALUES (
  'msg_user_1',
  '$SESSION_ID',
  $NOW_MS,
  $NOW_MS,
  '{"role":"user"}'
);
INSERT INTO message VALUES (
  'msg_assistant_1',
  '$SESSION_ID',
  $((NOW_MS + 1000)),
  $((NOW_MS + 1000)),
  '{"role":"assistant","finish":"stop","modelID":"test-model","tokens":{"total":42},"summary":{"diffs":[{"file":"README.md"}]}}'
);
INSERT INTO part VALUES (
  'prt_user_1',
  'msg_user_1',
  '$SESSION_ID',
  $NOW_MS,
  $NOW_MS,
  '{"type":"text","text":"write a justfile for startup"}'
);
INSERT INTO part VALUES (
  'prt_assistant_1',
  'msg_assistant_1',
  '$SESSION_ID',
  $((NOW_MS + 1000)),
  $((NOW_MS + 1000)),
  '{"type":"text","text":"Created the justfile."}'
);
SQL

run() {
  OPENCODE_DB="$DB" "$ROOT/sesh" "$@"
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  if [[ "$haystack" != *"$needle"* ]]; then
    printf 'Expected output to contain: %s\nActual output:\n%s\n' "$needle" "$haystack" >&2
    exit 1
  fi
}

assert_fails() {
  if run "$@" >"$TMPDIR/out" 2>"$TMPDIR/err"; then
    printf 'Expected command to fail: sesh %s\n' "$*" >&2
    exit 1
  fi
}

help_output="$(run --help)"
assert_contains "$help_output" "sesh log <id>"
assert_contains "$help_output" "sesh prompts <id>"

list_output="$(run list 1)"
assert_contains "$list_output" "$SESSION_ID"

search_output="$(run search justfile --content --limit 1)"
assert_contains "$search_output" "$SESSION_ID"

show_output="$(run show "$SESSION_ID")"
assert_contains "$show_output" "write a justfile for startup"
assert_contains "$show_output" "Created the justfile."

log_output="$(run log "$SESSION_ID" --limit 2)"
assert_contains "$log_output" "[USER]"
assert_contains "$log_output" "[ASSISTANT]"

prompts_output="$(run prompts "$SESSION_ID" --limit 1)"
assert_contains "$prompts_output" "write a justfile for startup"

files_output="$(run files "$SESSION_ID")"
assert_contains "$files_output" "README.md"

resume_output="$(run resume "$SESSION_ID")"
assert_contains "$resume_output" "opencode -s $SESSION_ID"

stats_output="$(run stats)"
assert_contains "$stats_output" "Total sessions:"

today_output="$(run today)"
assert_contains "$today_output" "$SESSION_ID"

config_output="$(run config)"
assert_contains "$config_output" "$DB"

plugin_output="$(
  cd "$ROOT"
  OPENCODE_DB="$DB" SESH_BIN="$ROOT/sesh" node --input-type=module <<'JS'
const { Sesh } = await import("./dist/index.js")
const plugin = Sesh()
const output = plugin.tool["sessions-global"].execute({
  cmd: "prompts",
  q: "ses_test1234567890",
  opts: "--limit 1",
})
process.stdout.write(output)
JS
)"
assert_contains "$plugin_output" "write a justfile for startup"

assert_fails show missing_session
assert_fails prompts "$SESSION_ID" --limit

printf 'E2E tests passed\n'
