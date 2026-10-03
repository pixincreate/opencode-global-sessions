#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

DB="$TMPDIR/opencode.db"
SESSION_ID="ses_test1234567890"
SUBAGENT_SESSION_ID="ses_subagent1234567"
OLD_SESSION_ID="ses_old9876543210"
RESUMED_SESSION_ID="ses_resumed7654321"
WEIRD_SESSION_ID="ses_weirdquote1234"
NO_FILE_SESSION_ID="ses_nofile1234567"
NOW_MS=$(( $(date +%s) * 1000 ))
OLD_MS=$(( NOW_MS - 3 * 86400 * 1000 ))
OLDER_MS=$(( NOW_MS - 10 * 86400 * 1000 ))

sqlite3 "$DB" <<SQL
CREATE TABLE project (
  id TEXT PRIMARY KEY,
  worktree TEXT NOT NULL,
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

INSERT INTO project VALUES ('proj_test', '/tmp/sesh-test-project', 'test-project');
INSERT INTO project VALUES ('proj_legacy', '/tmp/legacy-project', 'legacy-project');
INSERT INTO project VALUES ('proj_quote', '/tmp/sesh-target''s project', 'quote-project');
INSERT INTO project VALUES ('proj_dup_a', '/tmp/duplicate-project', 'duplicate-a');
INSERT INTO project VALUES ('proj_dup_b', '/tmp/duplicate-project', 'duplicate-b');

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
INSERT INTO session VALUES (
  '$RESUMED_SESSION_ID',
  'proj_test',
  '/tmp/sesh-test-project',
  'Old session resumed today',
  $OLD_MS,
  $NOW_MS,
  'test-agent',
  '{"id":"test-model","providerID":"test-provider"}',
  'test-version',
  0,
   1,
   1,
   0,
   0,
   0
);
INSERT INTO session VALUES (
  '$WEIRD_SESSION_ID',
  'proj_legacy',
  '/tmp/legacy-project',
  'Quote path move fixture',
  $OLDER_MS,
  $OLDER_MS,
  'test-agent',
  '{"id":"quote-model","providerID":"test-provider"}',
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
INSERT INTO message VALUES ('msg_resumed_user_1', '$RESUMED_SESSION_ID', $NOW_MS, $NOW_MS, '{"role":"user"}');
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

sqlite3 "$DB" "ALTER TABLE session ADD COLUMN parent_id TEXT;"
sqlite3 "$DB" "PRAGMA journal_mode=WAL;" >/dev/null

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
assert_contains "$help_output" "sesh move <id> <target-project-dir>"
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
assert_contains "$search_output" "updated"

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

move_help_output="$(run move --help)"
assert_contains "$move_help_output" "Usage: sesh move <session_id> <target-project-dir>"

old_session_before_move="$(sqlite3 -separator $'\t' "$DB" "SELECT project_id, directory, time_updated FROM session WHERE id = '$OLD_SESSION_ID';")"
old_updated_before="$(sqlite3 "$DB" "SELECT time_updated FROM session WHERE id = '$OLD_SESSION_ID';")"
old_message_count_before="$(sqlite3 "$DB" "SELECT count(*) FROM message WHERE session_id = '$OLD_SESSION_ID';")"
old_part_count_before="$(sqlite3 "$DB" "SELECT count(*) FROM part WHERE session_id = '$OLD_SESSION_ID';")"

assert_fails move
assert_fails move "$OLD_SESSION_ID"
assert_fails move "$OLD_SESSION_ID" /tmp/sesh-test-project --apply --dry-run
assert_fails move "$OLD_SESSION_ID" /tmp/sesh-test-project --wat
assert_fails move "$OLD_SESSION_ID" /tmp/duplicate-project --apply
old_session_after_invalid_moves="$(sqlite3 -separator $'\t' "$DB" "SELECT project_id, directory, time_updated FROM session WHERE id = '$OLD_SESSION_ID';")"
[[ "$old_session_after_invalid_moves" == "$old_session_before_move" ]] || { printf 'Expected invalid move attempts to leave session unchanged\n' >&2; exit 1; }

schema_db="$TMPDIR/no-worktree.db"
sqlite3 "$schema_db" <<SQL
CREATE TABLE project (id TEXT PRIMARY KEY, name TEXT);
SQL
if OPENCODE_DB="$schema_db" "$ROOT/sesh" move ses_schema /tmp/schema-project --apply >"$TMPDIR/schema-move.out" 2>"$TMPDIR/schema-move.err"; then
  printf 'Expected move to fail for unsupported project schema\n' >&2
  exit 1
fi
schema_move_err="$(<"$TMPDIR/schema-move.err")"
assert_contains "$schema_move_err" "unsupported OpenCode schema"

move_default_output="$(run move "$OLD_SESSION_ID" /tmp/sesh-test-project)"
assert_contains "$move_default_output" "No changes written"
old_session_after_default="$(sqlite3 -separator $'\t' "$DB" "SELECT project_id, directory, time_updated FROM session WHERE id = '$OLD_SESSION_ID';")"
[[ "$old_session_after_default" == "$old_session_before_move" ]] || { printf 'Expected default move to leave session unchanged\n' >&2; exit 1; }

move_dry_run_output="$(run move "$OLD_SESSION_ID" /tmp/sesh-test-project --dry-run)"
assert_contains "$move_dry_run_output" "No changes written"
old_session_after_dry_run="$(sqlite3 -separator $'\t' "$DB" "SELECT project_id, directory, time_updated FROM session WHERE id = '$OLD_SESSION_ID';")"
[[ "$old_session_after_dry_run" == "$old_session_before_move" ]] || { printf 'Expected dry-run move to leave session unchanged\n' >&2; exit 1; }

assert_fails move missing_session /tmp/sesh-test-project --apply
assert_fails move "$OLD_SESSION_ID" /tmp/not-an-opencode-project --apply
old_session_after_failed_move="$(sqlite3 -separator $'\t' "$DB" "SELECT project_id, directory, time_updated FROM session WHERE id = '$OLD_SESSION_ID';")"
[[ "$old_session_after_failed_move" == "$old_session_before_move" ]] || { printf 'Expected failed move to leave session unchanged\n' >&2; exit 1; }

weird_move_output="$(run move "$WEIRD_SESSION_ID" "/tmp/sesh-target's project" --apply)"
assert_contains "$weird_move_output" "project_id: proj_quote"
assert_contains "$weird_move_output" "directory:   /tmp/sesh-target's project"
weird_session_after_apply="$(sqlite3 -separator $'\t' "$DB" "SELECT project_id, directory FROM session WHERE id = '$WEIRD_SESSION_ID';")"
IFS=$'\t' read -r weird_project_after weird_dir_after <<< "$weird_session_after_apply"
[[ "$weird_project_after" == "proj_quote" ]] || { printf 'Expected weird-path session project_id to be proj_quote\n' >&2; exit 1; }
[[ "$weird_dir_after" == "/tmp/sesh-target's project" ]] || { printf 'Expected weird-path session directory to keep quote and space\n' >&2; exit 1; }

move_apply_output="$(run move "$OLD_SESSION_ID" /tmp/sesh-test-project --apply)"
assert_contains "$move_apply_output" "Backup created:"
assert_contains "$move_apply_output" "Moved session $OLD_SESSION_ID"

backup_path=""
while IFS= read -r line; do
  case "$line" in
    "Backup created: "*) backup_path="${line#Backup created: }";;
  esac
done <<< "$move_apply_output"
[[ -f "$backup_path" ]] || { printf 'Expected move --apply to create a readable DB backup\n' >&2; exit 1; }
backup_session_row="$(sqlite3 -separator $'\t' "$backup_path" "SELECT project_id, directory, time_updated FROM session WHERE id = '$OLD_SESSION_ID';")"
[[ "$backup_session_row" == "$old_session_before_move" ]] || { printf 'Expected DB backup to contain pre-move session row\n' >&2; exit 1; }

backup_files=("$TMPDIR"/opencode.db.sesh-backup-*)
[[ -e "${backup_files[0]}" ]] || { printf 'Expected move --apply to create a DB backup\n' >&2; exit 1; }

old_session_after_apply="$(sqlite3 -separator $'\t' "$DB" "SELECT project_id, directory, time_updated FROM session WHERE id = '$OLD_SESSION_ID';")"
IFS=$'\t' read -r old_project_after old_dir_after old_updated_after <<< "$old_session_after_apply"
[[ "$old_project_after" == "proj_test" ]] || { printf 'Expected moved session project_id to be proj_test\n' >&2; exit 1; }
[[ "$old_dir_after" == "/tmp/sesh-test-project" ]] || { printf 'Expected moved session directory to be /tmp/sesh-test-project\n' >&2; exit 1; }
[[ "$old_updated_after" -gt "$old_updated_before" ]] || { printf 'Expected moved session time_updated to increase\n' >&2; exit 1; }
old_message_count_after="$(sqlite3 "$DB" "SELECT count(*) FROM message WHERE session_id = '$OLD_SESSION_ID';")"
old_part_count_after="$(sqlite3 "$DB" "SELECT count(*) FROM part WHERE session_id = '$OLD_SESSION_ID';")"
[[ "$old_message_count_after" == "$old_message_count_before" ]] || { printf 'Expected move to preserve message rows\n' >&2; exit 1; }
[[ "$old_part_count_after" == "$old_part_count_before" ]] || { printf 'Expected move to preserve part rows\n' >&2; exit 1; }

moved_show_output="$(run show "$OLD_SESSION_ID")"
assert_contains "$moved_show_output" "Directory: /tmp/sesh-test-project"
assert_contains "$moved_show_output" "Project:   test-project"
moved_resume_output="$(run resume "$OLD_SESSION_ID")"
assert_contains "$moved_resume_output" "opencode -s $OLD_SESSION_ID"
moved_search_output="$(run search /tmp/sesh-test-project --limit 10)"
assert_contains "$moved_search_output" "$OLD_SESSION_ID"
legacy_dir_search_output="$(run search /tmp/legacy-project --limit 10)"
assert_not_contains "$legacy_dir_search_output" "$OLD_SESSION_ID"

backup_files_before_noop=("$TMPDIR"/opencode.db.sesh-backup-*)
backup_count_before_noop=0
if [[ -e "${backup_files_before_noop[0]}" ]]; then
  backup_count_before_noop=${#backup_files_before_noop[@]}
fi
assert_fails move "$OLD_SESSION_ID" /tmp/sesh-test-project --apply
backup_files_after_noop=("$TMPDIR"/opencode.db.sesh-backup-*)
backup_count_after_noop=0
if [[ -e "${backup_files_after_noop[0]}" ]]; then
  backup_count_after_noop=${#backup_files_after_noop[@]}
fi
[[ "$backup_count_after_noop" -eq "$backup_count_before_noop" ]] || { printf 'Expected no-op move to avoid creating a backup\n' >&2; exit 1; }

today_output="$(run today)"
assert_contains "$today_output" "$SESSION_ID"
assert_contains "$today_output" "$RESUMED_SESSION_ID"
assert_not_contains "$today_output" "$SUBAGENT_SESSION_ID"
assert_not_contains "$today_output" "$NO_FILE_SESSION_ID"

today_verbose_output="$(run today --verbose)"
assert_contains "$today_verbose_output" "$SUBAGENT_SESSION_ID"

stats_output="$(run stats)"
assert_contains "$stats_output" "Total sessions:      5"
assert_contains "$stats_output" "Total messages:      7"

stats_verbose_output="$(run stats --verbose)"
assert_contains "$stats_verbose_output" "Total sessions:      6"
assert_contains "$stats_verbose_output" "Total messages:      8"

config_output="$(run config)"
assert_contains "$config_output" "$DB"

# Native v2 storage: control messages are not conversational messages, and
# transcript sequence remains authoritative when timestamps tie.
legacy_db="$DB"
DB="$TMPDIR/v2.db"
sqlite3 "$DB" <<SQL
ATTACH DATABASE '$legacy_db' AS legacy;
CREATE TABLE project AS SELECT * FROM legacy.project;
CREATE TABLE session_v2 AS SELECT * FROM legacy.session WHERE id='$SESSION_ID';
UPDATE session_v2 SET title='V2 authoritative session';
CREATE TABLE session_message (id TEXT PRIMARY KEY,session_id TEXT,type TEXT,seq INTEGER,time_created INTEGER,time_updated INTEGER,data TEXT);
INSERT INTO session_message VALUES
('msg_v2_switch','$SESSION_ID','model-switched',1,$NOW_MS,$NOW_MS,'{"model":{"id":"test-model","providerID":"test-provider"},"time":{"created":$NOW_MS}}'),
('msg_v2_user','$SESSION_ID','user',2,$NOW_MS,$NOW_MS,'{"text":"v2 prompt with apostrophe: it''s valid","files":[],"agents":[],"skills":[],"time":{"created":$NOW_MS}}'),
('msg_v2_assistant','$SESSION_ID','assistant',3,$NOW_MS,$NOW_MS,'{"model":{"id":"test-model","providerID":"test-provider"},"agent":"build","time":{"created":$NOW_MS},"content":[{"type":"reasoning","text":"hidden-reasoning"},{"type":"text","text":"first-visible"},{"type":"tool","name":"shell","id":"tool1","state":{"status":"completed","input":{},"content":[{"type":"text","text":"hidden-tool-output"}]}},{"type":"text","text":"second-visible"}],"snapshot":{"files":["src/a.ts","src/b.ts"]},"finish":"stop"}');
SQL
sqlite3 "$DB" <<SQL
UPDATE session_message SET data=json_set(data,'$.tokens',json('{"input":10,"output":20,"reasoning":3,"cache":{"read":4,"write":5}}')) WHERE id='msg_v2_assistant';
INSERT INTO session_v2 SELECT * FROM session_v2 WHERE id='$SESSION_ID';
UPDATE session_v2 SET id='ses_v2_child',parent_id='$SESSION_ID',title='Investigate child logs',time_created=time_created+100,time_updated=time_updated+100 WHERE rowid=last_insert_rowid();
SQL
v2_before="$(sqlite3 "$DB" .dump)"
v2_list="$(run list --json)"
assert_contains "$v2_list" '"message_count":2'
assert_contains "$v2_list" 'V2 authoritative session'
assert_not_contains "$v2_list" 'ses_v2_child'
assert_contains "$(run list --verbose --json)" 'ses_v2_child'
assert_contains "$(run list 1 --json)" "$SESSION_ID"
assert_not_contains "$(run search Investigate --json)" 'ses_v2_child'
assert_contains "$(run search Investigate --verbose --json)" 'ses_v2_child'
assert_not_contains "$(run today)" 'ses_v2_child'
assert_contains "$(run stats)" 'Total sessions:      1'
assert_contains "$(run search "it's valid" --json)" "$SESSION_ID"
assert_contains "$(run prompts "$SESSION_ID")" "it's valid"
v2_log="$(run log "$SESSION_ID")"
[[ "$v2_log" == *"first-visible"*"second-visible"* ]] || { printf 'V2 log changed text content order\n' >&2; exit 1; }
assert_not_contains "$v2_log" "hidden-reasoning"
assert_not_contains "$v2_log" "hidden-tool-output"
assert_contains "$(run show "$SESSION_ID")" "2 total (1 user, 1 assistant)"
assert_contains "$(run show "$SESSION_ID")" "tokens: 42"
sqlite3 "$DB" "UPDATE session_message SET data=json_remove(data,'\$.tokens') WHERE id='msg_v2_assistant';"
assert_contains "$(run show "$SESSION_ID")" "tokens: ?"
sqlite3 "$DB" "UPDATE session_message SET data=json_set(data,'\$.tokens',json('{\"input\":10,\"output\":20,\"reasoning\":3,\"cache\":{\"read\":4,\"write\":5}}')) WHERE id='msg_v2_assistant';"
v2_before="$(sqlite3 "$DB" .dump)"
assert_contains "$(run files "$SESSION_ID")" "src/b.ts"
assert_contains "$(run today)" "$SESSION_ID"
assert_contains "$(run stats)" "Total messages:      2"
assert_fails move "$SESSION_ID" /tmp/sesh-test-project --apply
assert_fails move "$SESSION_ID" /tmp/sesh-test-project
[[ "$(sqlite3 "$DB" .dump)" == "$v2_before" ]] || { printf 'V2 read or rejected move changed database\n' >&2; exit 1; }
for backup in "$DB.sesh-backup-"*; do
  [[ ! -e "$backup" ]] || { printf 'Rejected move created backup\n' >&2; exit 1; }
done

assert_not_contains "$(run search hidden-reasoning --json)" "$SESSION_ID"
assert_not_contains "$(run search hidden-tool-output --json)" "$SESSION_ID"
sqlite3 "$DB" <<SQL
INSERT INTO session_v2 SELECT * FROM session_v2 WHERE id='$SESSION_ID';
UPDATE session_v2 SET id='ses_v2_empty',title=NULL,time_created=time_created+1,time_updated=time_updated+1 WHERE rowid=last_insert_rowid();
UPDATE session_message SET data=json_set(data,'$.content[1].text','edited-visible') WHERE id='msg_v2_assistant';
SQL
empty_list="$(run list 1 --json)"
assert_contains "$empty_list" 'ses_v2_empty'
assert_contains "$empty_list" '"title":null'
assert_contains "$empty_list" '"message_count":0'
assert_not_contains "$empty_list" "$SESSION_ID"
assert_contains "$(run show ses_v2_empty)" "0 total (0 user, 0 assistant)"
assert_not_contains "$(run log ses_v2_empty)" "edited-visible"
assert_contains "$(run log "$SESSION_ID")" "edited-visible"
assert_not_contains "$(run log "$SESSION_ID")" "first-visible"
assert_contains "$(run search edited-visible --json)" "$SESSION_ID"
assert_not_contains "$(run search first-visible --json)" "$SESSION_ID"

# A partially migrated DB exposes legacy-only IDs, never stale duplicate content.
sqlite3 "$DB" <<SQL
ATTACH DATABASE '$legacy_db' AS legacy;
CREATE TABLE session AS SELECT * FROM legacy.session;
CREATE TABLE message AS SELECT * FROM legacy.message;
CREATE TABLE part AS SELECT * FROM legacy.part;
SQL
mixed_list="$(run list --json)"
assert_contains "$mixed_list" 'V2 authoritative session'
assert_not_contains "$mixed_list" 'Test session with justfile'
assert_contains "$mixed_list" "$OLD_SESSION_ID"
assert_not_contains "$mixed_list" 'ses_v2_child'
assert_contains "$(run list --verbose --json)" 'ses_v2_child'
assert_contains "$(run show "$SESSION_ID")" 'tokens: 42'
assert_not_contains "$(run log "$SESSION_ID")" "marker-final"
assert_contains "$(run log "$OLD_SESSION_ID")" "legacy deployment notes"
assert_fails move "$OLD_SESSION_ID" /tmp/sesh-test-project --apply
sqlite3 "$DB" "UPDATE session SET time_created=9999999999999 WHERE id='$OLD_SESSION_ID';"
assert_contains "$(run list 1 --json)" "$OLD_SESSION_ID"
native_list="$(run list 1 --json --native-v2)"
assert_contains "$native_list" 'ses_v2_empty'
assert_not_contains "$native_list" "$OLD_SESSION_ID"
assert_not_contains "$(run list 100 --json --native-v2)" "$OLD_SESSION_ID"
DB="$legacy_db"
assert_fails list --json --native-v2

if OPENCODE_DB="$TMPDIR/missing.db" "$ROOT/sesh" list >"$TMPDIR/missing-db.out" 2>"$TMPDIR/missing-db.err"; then
  printf 'Expected missing database command to fail\n' >&2
  exit 1
fi
missing_db_err="$(<"$TMPDIR/missing-db.err")"
assert_contains "$missing_db_err" "Database not found"

installer_home="$TMPDIR/installer-home"
mkdir -p "$TMPDIR/detection-bin"
printf '#!/bin/sh\nprintf "opencode unknown\\n"\n' >"$TMPDIR/detection-bin/opencode"
chmod +x "$TMPDIR/detection-bin/opencode"
if PATH="$TMPDIR/detection-bin:$PATH" SESH_INSTALL_BIN_DIR="$installer_home/bin" SESH_INSTALL_CONFIG="$installer_home/cli.json" SESH_INSTALL_STATE_DIR="$installer_home/state" "$ROOT/scripts/install.sh" >"$TMPDIR/detection.out" 2>"$TMPDIR/detection.err"; then
  printf 'Expected ambiguous OpenCode version detection to fail\n' >&2
  exit 1
fi
assert_contains "$(<"$TMPDIR/detection.err")" "cannot detect OpenCode version"
[[ ! -e "$installer_home" ]] || { printf 'Failed detection must not create installation files\n' >&2; exit 1; }
installer_bin="$installer_home/.local/bin"
installer_config="$installer_home/.config/opencode/cli.json"
SESH_INSTALL_BIN_DIR="$installer_bin" \
  SESH_INSTALL_CONFIG="$installer_config" \
  SESH_INSTALL_STATE_DIR="$installer_home/.local/share/opencode-global-sessions" \
  SESH_INSTALL_CLI_SOURCE="$ROOT/sesh" \
  SESH_INSTALL_PLUGIN_SPEC="https://example.test/opencode-global-sessions-1.0.0.tgz" \
  "$ROOT/scripts/install.sh" --opencode-version 2 --version 1.0.0 >"$TMPDIR/install.out"
[[ -x "$installer_bin/sesh" ]] || { printf 'Expected installer to create executable sesh\n' >&2; exit 1; }
installer_config_content="$(<"$installer_config")"
assert_contains "$installer_config_content" "opencode-global-sessions:start"
assert_contains "$installer_config_content" "https://example.test/opencode-global-sessions-1.0.0.tgz"

SESH_INSTALL_BIN_DIR="$installer_bin" \
  SESH_INSTALL_CONFIG="$installer_config" \
  SESH_INSTALL_STATE_DIR="$installer_home/.local/share/opencode-global-sessions" \
  "$ROOT/scripts/install.sh" --opencode-version 2 --uninstall >"$TMPDIR/uninstall.out"
[[ ! -e "$installer_bin/sesh" ]] || { printf 'Expected uninstall to remove sesh\n' >&2; exit 1; }
installer_config_after_uninstall="$(<"$installer_config")"
assert_not_contains "$installer_config_after_uninstall" "opencode-global-sessions:start"

for major in 1 2; do
  key="plugin"
  [[ "$major" == 2 ]] && key="plugins"
  printf '{\n // "%s": ["example-plugin"],\n "%s": ["other-plugin"], "theme": "test"\n}\n' "$key" "$key" >"$installer_config"
  for _iteration in 1 2; do
    SESH_INSTALL_BIN_DIR="$installer_bin" SESH_INSTALL_CONFIG="$installer_config" \
      SESH_INSTALL_STATE_DIR="$installer_home/state" SESH_INSTALL_CLI_SOURCE="$ROOT/sesh" \
      SESH_INSTALL_PLUGIN_SPEC="opencode-global-sessions@2.0.0" \
      "$ROOT/scripts/install.sh" --opencode-version "$major" --version 2.0.0 >/dev/null
  done
  CONFIG="$installer_config" MAJOR="$major" node --input-type=module <<'JS'
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
const config = JSON.parse(readFileSync(process.env.CONFIG, "utf8").replace(/^\s*\/\/.*$/gm, "").replace(/,(\s*[\]}])/g, "$1"));
const entry = process.env.MAJOR === "1" ? ["opencode-global-sessions@2.0.0", { limit: 50 }] : { package: "opencode-global-sessions@2.0.0", options: { limit: 50 } };
assert.deepEqual(config, { [process.env.MAJOR === "1" ? "plugin" : "plugins"]: [entry, "other-plugin"], theme: "test" });
JS
  SESH_INSTALL_BIN_DIR="$installer_bin" SESH_INSTALL_CONFIG="$installer_config" \
    SESH_INSTALL_STATE_DIR="$installer_home/state" "$ROOT/scripts/install.sh" --opencode-version "$major" --uninstall >/dev/null
  CONFIG="$installer_config" KEY="$key" node --input-type=module <<'JS'
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
const config = JSON.parse(readFileSync(process.env.CONFIG, "utf8").replace(/^\s*\/\/.*$/gm, "").replace(/,(\s*[\]}])/g, "$1"));
assert.deepEqual(config, { [process.env.KEY]: ["other-plugin"], theme: "test" });
JS
  printf '{\n  // "%s": ["example-plugin"],\n  "theme": "test"\n}\n' "$key" >"$installer_config"
  for _iteration in 1 2; do
    SESH_INSTALL_BIN_DIR="$installer_bin" SESH_INSTALL_CONFIG="$installer_config" \
      SESH_INSTALL_STATE_DIR="$installer_home/state" SESH_INSTALL_CLI_SOURCE="$ROOT/sesh" \
      SESH_INSTALL_PLUGIN_SPEC="opencode-global-sessions@2.0.0" \
      "$ROOT/scripts/install.sh" --opencode-version "$major" --version 2.0.0 >/dev/null
  done
  CONFIG="$installer_config" KEY="$key" node --input-type=module <<'JS'
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
const config = JSON.parse(readFileSync(process.env.CONFIG, "utf8").replace(/^\s*\/\/.*$/gm, "").replace(/,(\s*[\]}])/g, "$1"));
assert.equal(config[process.env.KEY].length, 1);
assert.equal(config.theme, "test");
JS
  SESH_INSTALL_BIN_DIR="$installer_bin" SESH_INSTALL_CONFIG="$installer_config" \
    SESH_INSTALL_STATE_DIR="$installer_home/state" "$ROOT/scripts/install.sh" --opencode-version "$major" --uninstall >/dev/null
  printf '{\n /* example\n "%s": []\n */\n "theme": "test"\n}\n' "$key" >"$installer_config"
  cp "$installer_config" "$TMPDIR/comment-config-original"
  if SESH_INSTALL_BIN_DIR="$installer_bin" SESH_INSTALL_CONFIG="$installer_config" \
    SESH_INSTALL_STATE_DIR="$installer_home/state" SESH_INSTALL_CLI_SOURCE="$ROOT/sesh" \
    "$ROOT/scripts/install.sh" --opencode-version "$major" --version 2.0.0 >"$TMPDIR/block-comment.out" 2>"$TMPDIR/block-comment.err"; then
    printf 'Expected block-comment config to fail safely\n' >&2; exit 1
  fi
  assert_contains "$(<"$TMPDIR/block-comment.err")" 'Remove block comments'
  cmp "$installer_config" "$TMPDIR/comment-config-original"
done

fake_repo="$TMPDIR/fake-repo"
mkdir -p "$fake_repo/dist"
cp "$ROOT/sesh" "$fake_repo/sesh"
chmod +x "$fake_repo/sesh"
cat >"$fake_repo/package.json" <<'JSON'
{
  "scripts": {
    "build": "mkdir -p dist && cp tui-source.js dist/tui.js"
  }
}
JSON
printf 'export default { id: "fake" }\n' >"$fake_repo/tui-source.js"
git -C "$fake_repo" init -q
git -C "$fake_repo" add .
git -C "$fake_repo" -c user.email=test@example.com -c user.name=test commit -qm init

clone_home="$TMPDIR/clone-home"
clone_state="$clone_home/.local/share/opencode-global-sessions"
clone_repo="$clone_state/repo"
clone_bin="$clone_home/.local/bin"
clone_config="$clone_home/.config/opencode/cli.json"
SESH_INSTALL_BIN_DIR="$clone_bin" \
  SESH_INSTALL_CONFIG="$clone_config" \
  SESH_INSTALL_STATE_DIR="$clone_state" \
  SESH_INSTALL_REPO_DIR="$clone_repo" \
  SESH_INSTALL_REPO_URL="$fake_repo" \
  "$ROOT/scripts/install.sh" --opencode-version 2 --clone >"$TMPDIR/clone-install.out"
[[ -L "$clone_bin/sesh" ]] || { printf 'Expected clone install to symlink sesh\n' >&2; exit 1; }
clone_config_content="$(<"$clone_config")"
assert_contains "$clone_config_content" "$clone_repo/dist"

SESH_INSTALL_BIN_DIR="$clone_bin" \
  SESH_INSTALL_CONFIG="$clone_config" \
  SESH_INSTALL_STATE_DIR="$clone_state" \
  SESH_INSTALL_REPO_DIR="$clone_repo" \
  "$ROOT/scripts/install.sh" --opencode-version 2 --uninstall >"$TMPDIR/clone-uninstall.out"
[[ ! -e "$clone_bin/sesh" ]] || { printf 'Expected clone uninstall to remove sesh symlink\n' >&2; exit 1; }
[[ ! -e "$clone_repo" ]] || { printf 'Expected clone uninstall to remove managed repo\n' >&2; exit 1; }

printf '#!/bin/sh\nprintf "[]\\n"\n' >"$TMPDIR/empty-sesh"
printf '#!/bin/sh\nprintf "not-json\\n"\n' >"$TMPDIR/invalid-sesh"
printf '#!/bin/sh\nprintf "fixture database unavailable\\n" >&2\nexit 1\n' >"$TMPDIR/failing-sesh"
chmod +x "$TMPDIR/empty-sesh" "$TMPDIR/invalid-sesh" "$TMPDIR/failing-sesh"
tui_output="$(
  cd "$ROOT"
  OPENCODE_DB="$DB" SESH_TEST_NATIVE_DB="$TMPDIR/v2.db" SESH_BIN="$ROOT/sesh" SESH_TEST_EMPTY_BIN="$TMPDIR/empty-sesh" SESH_TEST_INVALID_BIN="$TMPDIR/invalid-sesh" SESH_TEST_FAIL_BIN="$TMPDIR/failing-sesh" node --input-type=module <<'JS'
const mod = await import("./dist/tui.js")
const plugin = mod.default
const assert = (condition, message) => {
  if (!condition) throw new Error(message)
}

let slotClaim
const layers = []
let navigated
let toast
let dialogSet
let selected
let unregistered = false
let dialogOpened = false

const context = {
  options: { limit: 1 },
  keymap: {
    layer(input) {
      layers.push(input())
    },
  },
  ui: {
    slot(claim) {
      slotClaim = claim
      return () => {
        unregistered = true
      }
    },
    toast: {
      show(input) {
        toast = input
      },
    },
    dialog: {
      set(options) {
        dialogSet = options
      },
      select(options) {
        dialogOpened = true
        selected = options
        // The host resolves the selected option to its value.
        return Promise.resolve(options.options[0].value)
      },
    },
    router: {
      navigate(destination) {
        navigated = destination
      },
    },
  },
}

const cleanup = await plugin.setup(context)
slotClaim.render({})
const layer = layers[0]
const command = layer.commands[0]

const legacyDB = process.env.OPENCODE_DB
process.env.OPENCODE_DB = process.env.SESH_TEST_NATIVE_DB
await command.run()
assert(selected.options.length === 1, "picker should show one fixture session")
assert(selected.options[0].value.id === "ses_v2_empty", "v2 picker must offer native sessions before applying its limit")
assert(navigated.type === "session", "selecting should navigate to the session route")
assert(navigated.sessionID === "ses_v2_empty", "selecting should pass native sessionID")

navigated = undefined
context.ui.dialog.select = () => { dialogOpened = true; return Promise.resolve(undefined) }
await command.run()
assert(navigated === undefined, "cancelling must not navigate")

let legacyCommand
process.env.OPENCODE_DB = legacyDB
let legacyDestination
let cancelLegacy = false
const api = {
  keymap: { registerLayer(layer) { legacyCommand = layer.commands[0]; return () => {} } },
  route: { navigate(name, params) { legacyDestination = { name, params } } },
  ui: {
    toast(input) { toast = input },
    dialog: {
      setSize() {}, clear() {},
      replace(render, onClose) { dialogOpened = true; if (cancelLegacy) onClose(); else render() },
    },
    DialogSelect(input) { input.onSelect(input.options[0]); return null },
  },
}
await plugin.tui(api, { limit: 1 })
await legacyCommand.run()
assert(legacyDestination.name === "session" && legacyDestination.params.sessionID === "ses_test1234567890", "v1 selection must open selected session")
legacyDestination = undefined
cancelLegacy = true
await legacyCommand.run()
assert(legacyDestination === undefined, "v1 cancellation must not navigate")

process.env.SESH_BIN = "/tmp/definitely-missing-sesh"
toast = undefined
await command.run()
assert(toast.variant === "error", "missing sesh should show error toast")
assert(toast.message.includes("sesh binary not found"), "missing sesh error should be user-visible")

for (const run of [() => command.run(), () => legacyCommand.run()]) {
  process.env.SESH_BIN = process.env.SESH_TEST_EMPTY_BIN
  toast = undefined
  navigated = undefined
  legacyDestination = undefined
  selected = undefined
  dialogOpened = false
  await run()
  assert(toast.variant === "info" && toast.message.includes("No global sessions"), "empty inventory should show information")
  assert(navigated === undefined && legacyDestination === undefined && !dialogOpened, "empty inventory must not open a picker or navigate")
  process.env.SESH_BIN = process.env.SESH_TEST_INVALID_BIN
  toast = undefined
  await run()
  assert(toast.variant === "error", "invalid CLI JSON should show a visible error")
  assert(navigated === undefined && legacyDestination === undefined, "invalid inventory must not navigate")
  process.env.SESH_BIN = process.env.SESH_TEST_FAIL_BIN
  toast = undefined
  await run()
  assert(toast.variant === "error" && toast.message.includes("fixture database unavailable"), "CLI failure should preserve its actionable diagnostic")
}

cleanup()
assert(unregistered, "cleanup should unregister the slot")

process.stdout.write("tui ok")
JS
)"
assert_contains "$tui_output" "tui ok"

printf 'E2E tests passed\n'
