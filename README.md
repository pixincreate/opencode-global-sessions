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
- open a native OpenCode picker with `/sessions-global`

The TUI plugin is intentionally thin. It calls the `sesh` CLI under the hood and shows the result inside OpenCode.

## Lore

I kept opening random projects from random directories, then later I could not find the OpenCode session I wanted because it belonged to some other directory I no longer remembered.

After poking around OpenCode's local database and running SQL against `~/.local`, I realized the data was already there. I just needed a small tool to make those sessions searchable from anywhere.

## Installation

There are two parts:

1. the `sesh` CLI
2. the optional OpenCode TUI plugin

The plugin needs the CLI. Install the CLI first.

### 1. Install the CLI

```bash
curl -fsSL https://raw.githubusercontent.com/pixincreate/opencode-global-sessions/master/sesh -o ~/.local/bin/sesh
chmod +x ~/.local/bin/sesh
```

Check it:

```bash
sesh list
```

### 2. Install the OpenCode TUI plugin

After a GitHub release exists, add the release tarball to `~/.config/opencode/tui.jsonc`:

```jsonc
{
  "plugin": [
    [
      "https://github.com/pixincreate/opencode-global-sessions/releases/download/vX.Y.Z/opencode-global-sessions-X.Y.Z.tgz",
      { "limit": 50 },
    ],
  ],
}
```

Replace `X.Y.Z` with the release version.

Restart OpenCode and run:

```text
/sessions-global
```

### Development install

Use this before a release exists, or when working on the plugin locally:

```bash
git clone https://github.com/pixincreate/opencode-global-sessions.git
cd opencode-global-sessions
npm install
npm run build
ln -sf "$PWD/sesh" ~/.local/bin/sesh
```

Then point OpenCode at the built plugin:

```jsonc
{
  "plugin": [
    ["/absolute/path/to/opencode-global-sessions/dist/tui.js", { "limit": 50 }],
  ],
}
```

If you do not want an absolute path in your dotfiles, use an env var:

```jsonc
{
  "plugin": [["{env:SESH_TUI_PLUGIN}", { "limit": 50 }]],
}
```

Then set it locally:

```bash
export SESH_TUI_PLUGIN="/absolute/path/to/opencode-global-sessions/dist/tui.js"
```

If the CLI is not at `~/.local/bin/sesh`, set:

```bash
export SESH_BIN="/absolute/path/to/sesh"
```

## Uninstallation

Remove the CLI:

```bash
rm -f ~/.local/bin/sesh
```

Remove the plugin entry from:

```text
~/.config/opencode/tui.jsonc
```

If you set these env vars, remove them from your shell config too:

```bash
SESH_TUI_PLUGIN
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

| Command           | What it does                                          |
| ----------------- | ----------------------------------------------------- |
| `sesh list [n]`   | list recent sessions                                  |
| `sesh search q`   | search titles, directories, prompts, and text replies |
| `sesh show id`    | show session details                                  |
| `sesh log id`     | show user and assistant text                          |
| `sesh prompts id` | show user prompts only                                |
| `sesh files id`   | list files touched in a session                       |
| `sesh resume id`  | print `opencode -s id`                                |
| `sesh today`      | list sessions from the last 24 hours                  |
| `sesh stats`      | show simple database stats                            |
| `sesh config`     | show paths and environment                            |

Examples:

```bash
sesh list 25 --json
sesh search checkout --since 7d --limit 5
sesh search webhook --fuzzy
sesh log ses_xxx --limit 20
sesh resume ses_xxx
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

## How it works

OpenCode stores sessions in:

```text
~/.local/share/opencode/opencode.db
```

`sesh` reads that SQLite database directly:

- `session` has session metadata
- `message` has message metadata
- `part.data` has prompt and response text rows

The CLI reads the database. The OpenCode TUI plugin calls:

```bash
sesh list <limit> --json
```

Then it renders those rows in an OpenCode picker.

`sesh` treats the database as read-only. It does not modify OpenCode data.

## Development

Run the full local check:

```bash
npm run check
```

That runs ShellCheck, builds the TUI plugin, and runs E2E tests against a temporary SQLite database.

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
