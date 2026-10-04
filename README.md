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

### From npm

Use this package on OpenCode v1 and v2.

On v2, add the package to `plugins` in `~/.config/opencode/cli.json`:

```jsonc
{
  "plugins": ["opencode-global-sessions"]
}
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
The package bundles the `sesh` CLI, so the picker works without any other setup.

A bare package name resolves to the latest version once and stays on it.
To update, pin the package version you want and restart OpenCode.

The npm install does not put `sesh` on your `PATH`.
To use the CLI directly, run the installer below.

### One-line install

The installer installs both parts:

- the `sesh` CLI at `~/.local/bin/sesh`
- the plugin entry in `tui.jsonc` on v1 or `cli.json` on v2

Use line comments (`//`) in installer-managed configuration.
The installer rejects block comments (`/* ... */`) without changing your configuration.

By default it uses the latest GitHub release for the CLI and the matching npm package for the plugin entry.
It detects `opencode --version`.
Pass `--opencode-version 1` or `--opencode-version 2` to select the host explicitly.

```bash
curl -fsSL https://raw.githubusercontent.com/pixincreate/opencode-global-sessions/master/scripts/install.sh | bash
```

Check it:

```bash
sesh list
```

Restart OpenCode and run:

```text
/sessions-global
```

To install a specific release:

```bash
curl -fsSL https://raw.githubusercontent.com/pixincreate/opencode-global-sessions/master/scripts/install.sh | bash -s -- --version 1.0.0
```

### Development install

Use clone mode when working on the plugin locally.
It clones the repo, builds the plugin, and symlinks the CLI to `~/.local/bin/sesh`.
V1 loads `dist/tui.js`; v2 loads the `dist` directory.

```bash
curl -fsSL https://raw.githubusercontent.com/pixincreate/opencode-global-sessions/master/scripts/install.sh | bash -s -- --clone
```

If you keep the CLI somewhere else, tell the plugin where it is:

```bash
export SESH_BIN="/absolute/path/to/sesh"
```

## Uninstallation

Run the installer in uninstall mode:

```bash
curl -fsSL https://raw.githubusercontent.com/pixincreate/opencode-global-sessions/master/scripts/install.sh | bash -s -- --uninstall
```

This removes `~/.local/bin/sesh` and the managed entry from the selected host's configuration.
Use the same `--opencode-version` value you used to install.
If you set this env var manually, remove it from your shell config too:

```bash
SESH_BIN
```

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

That updates the package version, runs checks, commits the version bump, creates `v1.0.1`, and pushes the branch and tag. The release workflow attaches the package tarball to the GitHub release.

## Contribution

Keep the tool small.

Before opening a PR:

```bash
npm run check
```

Prefer changes that keep the CLI useful on its own. The TUI plugin should stay a thin wrapper around the CLI unless there is a strong reason to duplicate logic.

## License

[MIT](LICENSE)
