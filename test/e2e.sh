#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

DB="$TMPDIR/opencode.db"
SESSION_ID="ses_test1234567890"
SUBAGENT_SESSION_ID="ses_subagent1234567"
OLD_SESSION_ID="ses_old9876543210"
NO_FILE_SESSION_ID="ses_nofile1234567"
NOW_MS=$(( $(date +%s) * 1000 ))
OLD_MS=$(( NOW_MS - 3 * 86400 * 1000 ))
OLDER_MS=$(( NOW_MS - 10 * 86400 * 1000 ))

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
INSERT INTO project VALUES ('proj_legacy', 'legacy-project');

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
INSERT INTO session VALUES (
  '$SUBAGENT_SESSION_ID',
  'proj_test',
  '/tmp/sesh-test-project',
  'Review TUI plan (@explore subagent)',
  $((NOW_MS + 5000)),
  $((NOW_MS + 5000)),
  'explore',
  '{"id":"explore-model","providerID":"test-provider"}',
  'test-version',
  0,
  5,
  6,
  0,
  0,
  0
);
INSERT INTO session VALUES (
  '$OLD_SESSION_ID',
  'proj_legacy',
  '/tmp/legacy-project',
  'Legacy startup shell',
  $OLD_MS,
  $OLD_MS,
  'test-agent',
  '{"id":"legacy-model","providerID":"test-provider"}',
  'test-version',
  0,
  3,
  4,
  0,
  0,
  0
);
INSERT INTO session VALUES (
  '$NO_FILE_SESSION_ID',
  'proj_test',
  '/tmp/no-file-project',
  'Quiet config review',
  $OLDER_MS,
  $OLDER_MS,
  'test-agent',
  '{"id":"quiet-model","providerID":"test-provider"}',
  'test-version',
  0,
  1,
  1,
  0,
  0,
  0
);

INSERT INTO message VALUES ('msg_user_1', '$SESSION_ID', $NOW_MS, $NOW_MS, '{"role":"user"}');
INSERT INTO message VALUES (
  'msg_assistant_1',
  '$SESSION_ID',
  $((NOW_MS + 1000)),
  $((NOW_MS + 1000)),
  '{"role":"assistant","finish":"stop","modelID":"test-model","tokens":{"total":42},"summary":{"diffs":[{"file":"README.md"}]}}'
);
INSERT INTO message VALUES ('msg_user_2', '$SESSION_ID', $((NOW_MS + 2000)), $((NOW_MS + 2000)), '{"role":"user"}');
INSERT INTO message VALUES (
  'msg_assistant_2',
  '$SESSION_ID',
  $((NOW_MS + 3000)),
  $((NOW_MS + 3000)),
  '{"role":"assistant","finish":"tool-calls","modelID":"test-model","tokens":{"total":7},"summary":{"diffs":[{"file":"sesh"}]}}'
);
INSERT INTO message VALUES ('msg_old_user_1', '$OLD_SESSION_ID', $OLD_MS, $OLD_MS, '{"role":"user"}');
INSERT INTO message VALUES ('msg_quiet_user_1', '$NO_FILE_SESSION_ID', $OLDER_MS, $OLDER_MS, '{"role":"user"}');
INSERT INTO message VALUES ('msg_subagent_user_1', '$SUBAGENT_SESSION_ID', $((NOW_MS + 5000)), $((NOW_MS + 5000)), '{"role":"user"}');

INSERT INTO part VALUES ('prt_user_1', 'msg_user_1', '$SESSION_ID', $NOW_MS, $NOW_MS, '{"type":"text","text":"write a justfile for startup"}');
INSERT INTO part VALUES (
  'prt_assistant_1',
  'msg_assistant_1',
  '$SESSION_ID',
  $((NOW_MS + 1000)),
  $((NOW_MS + 1000)),
  '{"type":"text","text":"Created the justfile with a long response that must not be truncated. marker-000 marker-001 marker-002 marker-003 marker-004 marker-005 marker-006 marker-007 marker-008 marker-009 marker-010 marker-011 marker-012 marker-013 marker-014 marker-015 marker-016 marker-017 marker-018 marker-019 marker-020 marker-021 marker-022 marker-023 marker-024 marker-025 marker-026 marker-027 marker-028 marker-029 marker-030 marker-031 marker-032 marker-033 marker-034 marker-035 marker-036 marker-037 marker-038 marker-039 marker-040 marker-041 marker-042 marker-043 marker-044 marker-045 marker-046 marker-047 marker-048 marker-049 marker-final"}'
);
INSERT INTO part VALUES ('prt_user_2', 'msg_user_2', '$SESSION_ID', $((NOW_MS + 2000)), $((NOW_MS + 2000)), '{"type":"text","text":"please add README docs for sesh"}');
INSERT INTO part VALUES ('prt_assistant_2', 'msg_assistant_2', '$SESSION_ID', $((NOW_MS + 3000)), $((NOW_MS + 3000)), '{"type":"text","text":"Updated shell CLI behavior."}');
INSERT INTO part VALUES ('prt_old_user_1', 'msg_old_user_1', '$OLD_SESSION_ID', $OLD_MS, $OLD_MS, '{"type":"text","text":"legacy deployment notes mention tartarus service"}');
INSERT INTO part VALUES ('prt_quiet_user_1', 'msg_quiet_user_1', '$NO_FILE_SESSION_ID', $OLDER_MS, $OLDER_MS, '{"type":"text","text":"quiet config review without file changes"}');
INSERT INTO part VALUES ('prt_subagent_user_1', 'msg_subagent_user_1', '$SUBAGENT_SESSION_ID', $((NOW_MS + 5000)), $((NOW_MS + 5000)), '{"type":"text","text":"subagent-marker internal exploration"}');
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

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  if [[ "$haystack" == *"$needle"* ]]; then
    printf 'Expected output not to contain: %s\nActual output:\n%s\n' "$needle" "$haystack" >&2
    exit 1
  fi
}

assert_fails() {
  if run "$@" >"$TMPDIR/out" 2>"$TMPDIR/err"; then
    printf 'Expected command to fail: sesh %s\n' "$*" >&2
    exit 1
  fi
}

json_assert() {
  local json="$1"
  local script="$2"
  JSON_INPUT="$json" NODE_SCRIPT="$script" node --input-type=module <<'JS'
const data = JSON.parse(process.env.JSON_INPUT)
const assert = (condition, message) => {
  if (!condition) throw new Error(message)
}
eval(process.env.NODE_SCRIPT)
JS
}

help_output="$(run --help)"
assert_contains "$help_output" "sesh list [n] [--json]"
assert_contains "$help_output" "sesh log <id>"
assert_contains "$help_output" "sesh prompts <id>"
assert_contains "$help_output" "--verbose"

default_output="$(run)"
list_output="$(run list 1)"
assert_contains "$default_output" "$SESSION_ID"
assert_contains "$list_output" "$SESSION_ID"
assert_not_contains "$default_output" "$SUBAGENT_SESSION_ID"
assert_not_contains "$list_output" "$SUBAGENT_SESSION_ID"
assert_not_contains "$list_output" "$OLD_SESSION_ID"

verbose_list_output="$(run list 1 --verbose)"
assert_contains "$verbose_list_output" "$SUBAGENT_SESSION_ID"

list_json_output="$(run list 2 --json)"
json_assert "$list_json_output" 'assert(Array.isArray(data), "list --json should be an array"); assert(data.length === 2, "list 2 --json should return two rows"); assert(data[0].id === "ses_test1234567890", "newest session should be first"); assert(data[0].message_count === 4, "message_count should be included")'

verbose_list_json_output="$(run list 1 --json --verbose)"
json_assert "$verbose_list_json_output" 'assert(data.length === 1, "verbose list should honor limit"); assert(data[0].id === "ses_subagent1234567", "verbose list should include subagent sessions")'

assert_fails list 0
assert_fails list nope
assert_fails list --wat

search_output="$(run search justfile --limit 1)"
assert_contains "$search_output" "$SESSION_ID"

content_search_output="$(run search marker-final --limit 1)"
assert_contains "$content_search_output" "$SESSION_ID"

subagent_search_output="$(run search subagent-marker --limit 5)"
assert_not_contains "$subagent_search_output" "$SUBAGENT_SESSION_ID"

verbose_subagent_search_output="$(run search subagent-marker --limit 5 --verbose)"
assert_contains "$verbose_subagent_search_output" "$SUBAGENT_SESSION_ID"

fuzzy_output="$(run search 'legacy tartarus' --fuzzy --limit 5)"
assert_contains "$fuzzy_output" "$OLD_SESSION_ID"

search_json_output="$(run search marker-final --json --limit 1)"
json_assert "$search_json_output" 'assert(Array.isArray(data), "search --json should be an array"); assert(data.length === 1, "search --json limit should apply"); assert(data[0].id === "ses_test1234567890", "search --json should return content match")'

since_output="$(run search tartarus --since 1d --limit 5)"
assert_not_contains "$since_output" "$OLD_SESSION_ID"

until_output="$(run search tartarus --until 1d --limit 5)"
assert_contains "$until_output" "$OLD_SESSION_ID"

assert_fails search
assert_fails search justfile --limit
assert_fails search justfile --limit nope
assert_fails search justfile --since
assert_fails search justfile --until

show_output="$(run show "$SESSION_ID")"
assert_contains "$show_output" "Session details"
assert_contains "$show_output" "write a justfile for startup"
assert_contains "$show_output" "Created the justfile"
assert_contains "$show_output" "Messages:    4 total"
assert_contains "$show_output" "README.md"

log_output="$(run log "$SESSION_ID" --limit 4)"
assert_contains "$log_output" "[USER]"
assert_contains "$log_output" "[ASSISTANT]"
assert_contains "$log_output" "marker-final"
assert_contains "$log_output" "please add README docs for sesh"

log_limit_output="$(run log "$SESSION_ID" --limit 1)"
assert_contains "$log_limit_output" "write a justfile for startup"
assert_not_contains "$log_limit_output" "Created the justfile"

prompts_output="$(run prompts "$SESSION_ID" --limit 5)"
assert_contains "$prompts_output" "write a justfile for startup"
assert_contains "$prompts_output" "please add README docs for sesh"
assert_not_contains "$prompts_output" "Created the justfile"

assert_fails log missing_session
assert_fails prompts "$SESSION_ID" --limit
assert_fails prompts "$SESSION_ID" --limit nope

files_output="$(run files "$SESSION_ID")"
assert_contains "$files_output" "README.md"
assert_contains "$files_output" "sesh"

no_files_output="$(run files "$NO_FILE_SESSION_ID")"
assert_contains "$no_files_output" "No file diffs found"

resume_output="$(run resume "$SESSION_ID")"
assert_contains "$resume_output" "opencode -s $SESSION_ID"
assert_fails resume missing_session

today_output="$(run today)"
assert_contains "$today_output" "$SESSION_ID"
assert_not_contains "$today_output" "$SUBAGENT_SESSION_ID"
assert_not_contains "$today_output" "$OLD_SESSION_ID"

today_verbose_output="$(run today --verbose)"
assert_contains "$today_verbose_output" "$SUBAGENT_SESSION_ID"

stats_output="$(run stats)"
assert_contains "$stats_output" "Total sessions:      3"
assert_contains "$stats_output" "Total messages:      6"

stats_verbose_output="$(run stats --verbose)"
assert_contains "$stats_verbose_output" "Total sessions:      4"
assert_contains "$stats_verbose_output" "Total messages:      7"

config_output="$(run config)"
assert_contains "$config_output" "$DB"

if OPENCODE_DB="$TMPDIR/missing.db" "$ROOT/sesh" list >"$TMPDIR/missing-db.out" 2>"$TMPDIR/missing-db.err"; then
  printf 'Expected missing database command to fail\n' >&2
  exit 1
fi
missing_db_err="$(<"$TMPDIR/missing-db.err")"
assert_contains "$missing_db_err" "Database not found"

tui_output="$(
  cd "$ROOT"
  OPENCODE_DB="$DB" SESH_BIN="$ROOT/sesh" node --input-type=module <<'JS'
const mod = await import("./dist/tui.js")
const plugin = mod.default
const assert = (condition, message) => {
  if (!condition) throw new Error(message)
}

assert(plugin.id === "opencode-global-sessions.tui", "tui plugin should have stable id")
assert(typeof plugin.tui === "function", "tui plugin should export tui function")

let registeredLayer
let selectedProps
let navigated
let toast
let dialogSize
let cleared = false

const api = {
  keymap: {
    registerLayer(layer) {
      registeredLayer = layer
      return () => {}
    },
  },
  ui: {
    dialog: {
      setSize(size) {
        dialogSize = size
      },
      replace(render) {
        dialogSize = "medium"
        render()
      },
      clear() {
        cleared = true
      },
      size: "medium",
      depth: 0,
      open: false,
    },
    DialogSelect(props) {
      selectedProps = props
      return null
    },
    toast(input) {
      toast = input
    },
  },
  route: {
    current: { name: "home" },
    navigate(name, params) {
      navigated = { name, params }
    },
  },
}

await plugin.tui(api, { limit: 1 }, {})
assert(registeredLayer.commands.length === 1, "tui should register one command")
const command = registeredLayer.commands[0]
assert(command.title === "Sesh: recent sessions", "command title should match plan")
assert(command.category === "Sessions", "command category should match plan")
assert(command.slashName === "sessions-global", "slash command should be /sessions-global")

await command.run({})
assert(dialogSize === "xlarge", "picker should use a wide dialog")
assert(selectedProps.title === "Recent global sessions", "picker title should match plan")
assert(selectedProps.options.length === 1, "picker should show one fixture session")
assert(selectedProps.options[0].value.id === "ses_test1234567890", "picker option should contain session id")

selectedProps.onSelect(selectedProps.options[0])
assert(cleared, "selecting should clear dialog")
assert(navigated.name === "session", "selecting should navigate to session route")
assert(navigated.params.sessionID === "ses_test1234567890", "selecting should pass sessionID")

process.env.SESH_BIN = "/tmp/definitely-missing-sesh"
selectedProps = undefined
toast = undefined
await command.run({})
assert(toast.variant === "error", "missing sesh should show error toast")
assert(toast.message.includes("sesh binary not found"), "missing sesh error should be user-visible")

process.stdout.write("tui ok")
JS
)"
assert_contains "$tui_output" "tui ok"

printf 'E2E tests passed\n'
