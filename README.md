# opencode-global-sessions - sesh

## Description

`sesh` helps you find OpenCode sessions across every project on your machine.

OpenCode stores sessions globally, but the built-in `/sessions` view is scoped to the current project. `sesh` gives you a small CLI and an OpenCode TUI picker for searching those sessions from anywhere.

It can:

- list recent sessions
- search titles, directories, prompts, and text responses
- show logs and prompts
- show files touched in a session
- print the command to resume a session
- move a session to an existing OpenCode project
- open a native OpenCode picker with `/sessions-global`

The TUI plugin is intentionally thin. It calls the `sesh` CLI under the hood and shows the result inside OpenCode.

## Lore

I kept opening random projects from random directories, then later I could not find the OpenCode session I wanted because it belonged to some other directory I no longer remembered.

After poking around OpenCode's local database and running SQL against `~/.local`, I realized the data was already there. I just needed a small tool to make those sessions searchable from anywhere.

## Installation

### The plugin (OpenCode)

Use this package on OpenCode v1 and v2.

On v2, add the package to `plugins` in `~/.config/opencode/cli.json`:

```jsonc
{
  "plugins": ["opencode-global-sessions"]
}
```

Or use the OpenCode CLI:

```bash
opencode plugin add opencode-global-sessions
```

On v1, add it to `plugin` in `~/.config/opencode/tui.jsonc`:

```json
{
  "plugin": [["opencode-global-sessions", { "limit": 100 }]]
}
```

To change the picker size, pass options:

```jsonc
{
  "plugins": [
    { "package": "opencode-global-sessions", "options": { "limit": 100 } }
  ]
}
```

Restart OpenCode and run `/sessions-global`.
OpenCode installs the package from npm on first start and caches it.
The package bundles its own `sesh` copy, so the picker works with no other setup.

A bare package name resolves to the latest version once and is held.
OpenCode does not re-check npm on every start.
To update, run:

```bash
opencode plugin update
```

Or pin a version in `cli.json`, for example `opencode-global-sessions@3.0.0`.

### The sesh CLI (optional)

The plugin does not put `sesh` on your `PATH`.
Install the CLI to run `sesh` in a shell.
The installer asks before it adds the CLI, then keeps a managed copy and links it:

```bash
curl -fsSL https://raw.githubusercontent.com/pixincreate/opencode-global-sessions/master/scripts/install.sh | bash
```

- Answer the prompt to link `sesh` to `~/.local/bin/sesh`. The default is yes.
- The managed copy lives at `~/.local/share/opencode-global-sessions/sesh`.
- Pass `--cli` to install without a prompt, or `--no-cli` to skip the CLI.

Check it:

```bash
sesh list
```

To install the CLI from a specific release:

```bash
curl -fsSL https://raw.githubusercontent.com/pixincreate/opencode-global-sessions/master/scripts/install.sh | bash -s -- --version 3.0.0
```

If the CLI lives somewhere else, tell the plugin where it is:

```bash
export SESH_BIN="/absolute/path/to/sesh"
```

## Uninstallation

Remove the plugin with `opencode plugin remove opencode-global-sessions`, or delete its entry from `cli.json` or `tui.jsonc`.

Remove the CLI with the installer:

```bash
curl -fsSL https://raw.githubusercontent.com/pixincreate/opencode-global-sessions/master/scripts/install.sh | bash -s -- --uninstall
```

That removes the `~/.local/bin/sesh` symlink and the managed copy.
If you set `SESH_BIN` in your shell config, remove it too.

## Usage

### OpenCode

Run this inside OpenCode:

```text
/sessions-global
```

![OpenCode command palette showing sessions-global](https://github.com/user-attachments/assets/f33acd88-ab9e-4bf8-9efa-509b810a4eb1)

Pick a session:

![OpenCode global sessions picker](https://github.com/user-attachments/assets/1fded646-4f68-445d-810f-c82510f309e2)

### CLI

| Command            | What it does                                          |
| ------------------ | ----------------------------------------------------- |
| `sesh list [n]`    | list recent sessions                                  |
| `sesh search q`    | search titles, directories, prompts, and text replies |
| `sesh index`       | build or rebuild the local search index               |
| `sesh show id`     | show session details                                  |
| `sesh log id`      | show user and assistant text                          |
| `sesh prompts id`  | show user prompts only                                |
| `sesh files id`    | list files touched in a session                       |
| `sesh resume id`   | print `opencode -s id`                                |
| `sesh move id dir` | move a session to an existing OpenCode project        |
| `sesh today`       | list sessions active in the last 24 hours          |
| `sesh stats`       | show simple database stats                            |
| `sesh config`      | show paths and environment                            |

Examples:

```bash
sesh list 25 --json
sesh search checkout --since 7d --limit 5
sesh search webhook --fuzzy
sesh search checkout --title
sesh index --rebuild
sesh log ses_xxx --limit 20
sesh resume ses_xxx
sesh move ses_xxx /path/to/project
sesh move ses_xxx /path/to/project --apply
```

OpenCode subagent sessions are hidden from discovery commands by default. Add `--verbose` to include them:

```bash
sesh list --verbose
sesh search tui --verbose
```

### Search index

On v2-only databases, `sesh search` uses a local FTS5 index to avoid scanning message content.
The index lives at:

```text
~/.cache/sesh/index.db
```

The first search builds the index and prints a one-time notice.
Later searches sync only changed sessions.

Manage the index with:

```bash
sesh index            # build or refresh
sesh index --rebuild  # rebuild from scratch
```

Search options:

- `--title` (alias `--no-content`) searches titles and directories only.
- `--no-index` skips the index and uses plain `LIKE` matching.
- `SESH_INDEX_DB` overrides the index path.

The index reads `opencode.db` in read-only mode and never modifies it.
Delete the index file at any time; the next search rebuilds it.

Direct commands still work if you already know the session ID:

```bash
sesh show ses_xxx
sesh log ses_xxx
```

`sesh move` is CLI-only. By default it prints the current and target project without writing anything. Add `--apply` to create a database backup and update the session.
Moves are supported only for v1-only databases.
V2 and mixed databases reject moves, including dry runs, because direct SQL updates bypass OpenCode's session events and workspace state.
Use OpenCode to move those sessions.

## How it works

OpenCode stores sessions in:

```text
~/.local/share/opencode/opencode.db
```

`sesh` uses that SQLite database directly:

- v1 `session` has session metadata
- `project` has OpenCode project worktrees
- `message` has message metadata
- `part.data` has prompt and response text rows
- v2 uses `session_v2` and inline text in `session_message`

Reads use temporary projections without changing the stored schema.
V2 takes precedence when both schemas contain the same session ID.
Legacy-only sessions remain readable.
Set `OPENCODE_DB` to override the database path.
The default respects `XDG_DATA_HOME`.

The CLI reads the database. The OpenCode TUI plugin calls:

```bash
sesh list <limit> --json
```

Then it renders those rows in an OpenCode picker.
The v2 picker adds `--native-v2` to list only sessions that the v2 server can open.
Ordinary CLI reads retain legacy-only sessions for inspection.
Listing counts messages directly from their source tables without normalizing transcript content.

Read commands enable SQLite query-only mode.
On v1-only databases, `sesh move ... --apply` creates a backup next to `opencode.db`, then updates one existing `session` row to point at an existing `project` row.
It does not alter the schema or run a migration.

## Development

Run the full local check:

```bash
npm run check
```

That runs ShellCheck, typechecks and builds the TUI plugin, and runs E2E tests against temporary v1, v2, and mixed SQLite databases.

Create a release:

```bash
npm run release -- 1.0.1
```

That updates the package version, runs checks, commits the version bump, creates `v1.0.1`, and pushes the branch and tag. The release workflow publishes the package to npm and attaches the tarball to the GitHub release.

## Contribution

Keep the tool small.

Before opening a PR:

```bash
npm run check
```

Prefer changes that keep the CLI useful on its own. The TUI plugin should stay a thin wrapper around the CLI unless there is a strong reason to duplicate logic.

## License

[MIT](LICENSE)
