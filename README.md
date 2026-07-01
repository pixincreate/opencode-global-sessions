# opencode-global-sessions

Global session search for OpenCode. Query sessions across all directories, not just the current one.

## Description

OpenCode's built-in session search only shows sessions from the current working directory. This tool queries the global SQLite database directly, allowing you to find sessions from any project without switching directories.

## Use Case

You work on multiple projects with OpenCode. Sometimes you start a session in project A, then switch to project B, then back to A. Later, you want to find that session you were working on 3 days ago - but you can't remember which directory it was in.

**Problem:** OpenCode's `/sessions` only shows sessions from the **current directory**.

**Solution:** This tool shows sessions from **ALL directories** globally.

## Quick Use

| Where    | Command                            |
| -------- | ---------------------------------- |
| Terminal | `sesh list`                        |
| Terminal | `sesh log <session_id>`            |
| Terminal | `sesh resume <session_id>`         |
| OpenCode | `/sessions-global`                 |
| OpenCode | `@sessions-global search keywatch` |

## Installation

`sesh` has two parts:

1. **Terminal CLI** - the `sesh` shell script. This is the core tool.
2. **OpenCode plugin** - an optional wrapper that lets you call the CLI from OpenCode.

### Option 1: Terminal CLI only (recommended)

Install only the shell script if you just want `sesh` in your terminal:

```bash
# Download sesh
curl -fsSL https://raw.githubusercontent.com/pixincreate/opencode-global-sessions/master/sesh > sesh

# Install to PATH (assumes ~/.local/bin is in your PATH)
chmod +x sesh
cp sesh ~/.local/bin/

# Verify it works
sesh list
```

This does **not** require cloning the repo.

### Option 2: Clone repo + OpenCode plugin

Use this if you want `/sessions-global` inside OpenCode. For the current plugin, yes: clone the repo, build it, and point OpenCode at the cloned directory.

```bash
git clone https://github.com/pixincreate/opencode-global-sessions.git
cd opencode-global-sessions
npm install
npm run build

# Install the CLI too. The plugin shells out to this binary.
chmod +x sesh
cp sesh ~/.local/bin/sesh
```

Add to `~/.config/opencode/opencode.jsonc`:

```json
{
  "plugin": ["/path/to/opencode-global-sessions"],
  "command": {
    "sessions-global": {
      "description": "List sessions from ALL directories",
      "template": "sessions-global list"
    }
  }
}
```

Restart OpenCode after changing plugin config.

### Option 3: Development symlink

For local development, symlink instead of copy so CLI changes reflect immediately:

```bash
git clone https://github.com/pixincreate/opencode-global-sessions.git
cd opencode-global-sessions
npm install
npm run build

ln -sf "$PWD/sesh" ~/.local/bin/sesh
```

Keep the same OpenCode plugin config as Option 2, pointing at the cloned repo directory.

### Future option: npm plugin

OpenCode can load npm plugins directly from the `plugin` config and install them automatically. If this project is published as an npm package later, the plugin install could become:

```json
{
  "plugin": ["opencode-global-sessions"]
}
```

Until then, the OpenCode plugin path must point at a local clone/build of this repo. The terminal CLI install still works without cloning.

### Plugin UI note

The current `sesh` OpenCode plugin is a server/tool plugin: it returns plain text output, just like running `sesh` from terminal.

OpenCode also has a separate TUI plugin system (`tui.json`) that can register routes, keybinds, dialogs, and UI components. `sesh` does not implement that yet. A native popup/session browser is possible as a future TUI plugin, but it would be separate from the current plain-text `/sessions-global` wrapper.

Set `SESH_BIN` in your shell config if sesh is not at `~/.local/bin/sesh`:

```bash
export SESH_BIN="/path/to/sesh"
```

### Development checks

Before committing changes, run:

```bash
npm run check
```

This runs:

1. `npm run shellcheck` — ShellCheck for `sesh` and `test/e2e.sh`
2. `npm run build` — rebuilds the TypeScript plugin
3. `npm test` — end-to-end CLI + plugin test against a temporary SQLite database

The test database is generated under a temp directory and does not read your real OpenCode database. GitHub Actions runs the same checks on Node.js 26.4.0.

## Usage

| Command          | Description                           |
| ---------------- | ------------------------------------- |
| `list [n]`       | List n recent sessions (default: 10)  |
| `search <query>` | Search sessions by title or directory |
| `show <id>`      | Show full session details             |
| `log <id>`       | Show user + assistant text log        |
| `prompts <id>`   | Show user prompts only                |
| `resume <id>`    | Print `opencode -s <id>`              |
| `files <id>`     | List files touched in a session       |
| `today`          | Sessions from the last 24 hours       |
| `stats`          | Aggregate session statistics          |
| `config`         | Show configuration and environment    |
| `interactive`    | Browse sessions interactively         |

### Search options

| Option           | Description                                   |
| ---------------- | --------------------------------------------- |
| `--content`      | Also search message content (slower)          |
| `--since <date>` | Filter by start date (ISO 8601 or `7d`)       |
| `--until <date>` | Filter by end date                            |
| `--limit <n>`    | Max results (default: 20)                     |
| `--fuzzy`        | Broader substring matching                    |
| `--json`         | Machine-readable JSON output (pipe to jq/fzf) |

### Log/prompts options

| Option        | Description                  |
| ------------- | ---------------------------- |
| `--limit <n>` | Max messages (default: 50)   |
| `--full`      | Do not truncate message text |

### Examples

```bash
sesh search justfile
sesh search justfile --content --since 7d
sesh search justfile --json | jq '.[].title'
sesh search shell --fuzzy
sesh log ses_xxxxxxxxxxxxxxxxxxxx
sesh prompts ses_xxxxxxxxxxxxxxxxxxxx --full
sesh resume ses_xxxxxxxxxxxxxxxxxxxx
sesh files ses_xxxxxxxxxxxxxxxxxxxx
sesh config
```

## Configuration

Override defaults via environment variables:

```bash
export OPENCODE_DB="/custom/path/to/opencode.db"
export SESH_BIN="/custom/path/to/sesh"
```

## How It Works

```
sesh (bash) ──> SQLite DB ──> Results
```

The `sesh` script queries `~/.local/share/opencode/opencode.db` directly using SQLite. It is a standalone bash script with no dependencies beyond `sqlite3` (which is installed on most systems).

OpenCode stores session metadata in `session`, message metadata in `message`, and actual text content in `part.data` rows where `type = "text"`. Commands such as `search --content`, `show`, `log`, and `prompts` join `message` with `part` so they show real prompt/response text instead of metadata-only placeholders.

## Limitations

The OpenCode database has a read-only schema — sesh cannot change what's stored.

- **Plain text is stored in `part.data`.** `sesh` reads text parts for prompts/responses. Non-text parts may contain tool metadata, reasoning, or attachments and are intentionally not expanded in the simple log view.
- **Tool output is not a full terminal transcript.** OpenCode stores structured parts and message metadata, not necessarily every rendered byte you saw in the TUI.
- **Current plugin returns plain text.** The existing `/sessions-global` wrapper is a server/tool plugin, not a TUI plugin. Commands like `interactive` and `fzf`-based flows work only in the terminal unless a separate TUI plugin is added later.
- **Resume is command-only.** `sesh resume <id>` prints `opencode -s <id>` so you can run it from any directory.

## License

[MIT LICENSE](LICENSE)
