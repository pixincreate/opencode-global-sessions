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

## Installation

`sesh` has two parts:

1. **Terminal CLI** - the `sesh` shell script. This is the core tool.
2. **OpenCode TUI plugin** - a native session picker for OpenCode's TUI.

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

### Option 2: Clone repo + native OpenCode TUI plugin

Use this if you want `/sessions-global` inside OpenCode. Clone the repo, build it, install the CLI, then point OpenCode's TUI config at the built TUI entrypoint.

```bash
git clone https://github.com/pixincreate/opencode-global-sessions.git
cd opencode-global-sessions
npm install
npm run build

# Install the CLI too. The plugin shells out to this binary.
chmod +x sesh
cp sesh ~/.local/bin/sesh
```

Add to `~/.config/opencode/tui.jsonc`:

```json
{
  "plugin": [
    ["/path/to/opencode-global-sessions/dist/tui.js", { "limit": 50 }]
  ]
}
```

Restart OpenCode. Open the command palette and run `Sesh: recent sessions`, or use `/sessions-global`.

This is a TUI plugin. It does **not** use `opencode.jsonc` `plugin`, and there is no legacy server/tool wrapper.

#### Dotfiles without hardcoded absolute paths

OpenCode config supports `{env:VAR}` substitution. Keep the real local path in an uncommitted shell file:

```bash
export SESH_TUI_PLUGIN="$HOME/dev/forge/scripts/sesh/dist/tui.js"
```

Then commit this portable `~/.config/opencode/tui.jsonc`:

```json
{
  "plugin": [
    ["{env:SESH_TUI_PLUGIN}", { "limit": 50 }]
  ]
}
```

You can also use a relative plugin path. OpenCode resolves relative plugin specs from the `tui.jsonc` file that declared them.

### Option 3: Development symlink

For local development, symlink instead of copy so CLI changes reflect immediately:

```bash
git clone https://github.com/pixincreate/opencode-global-sessions.git
cd opencode-global-sessions
npm install
npm run build

ln -sf "$PWD/sesh" ~/.local/bin/sesh
```

Keep the same TUI config as Option 2, pointing at the built `dist/tui.js` file.

### Option 4: GitHub release without npm registry

OpenCode installs non-local plugin specs through npm's package installer. That means a GitHub release can work **if the release asset is an npm package tarball**, not a raw `tui.js` file.

Create a release tarball locally:

```bash
npm pack
```

Attach the generated `opencode-global-sessions-*.tgz` file to a GitHub release. Then use the release asset URL in `~/.config/opencode/tui.jsonc`:

```json
{
  "plugin": [
    ["https://github.com/pixincreate/opencode-global-sessions/releases/download/v1.0.0/opencode-global-sessions-1.0.0.tgz", { "limit": 50 }]
  ]
}
```

You still need the CLI installed separately because the TUI plugin shells out to `sesh`:

```bash
curl -fsSL https://raw.githubusercontent.com/pixincreate/opencode-global-sessions/master/sesh > ~/.local/bin/sesh
chmod +x ~/.local/bin/sesh
```

For purely local installs, the simplest flow is:

1. Download a GitHub release asset or tarball.
2. Install `sesh` to `~/.local/bin/sesh`.
3. Install `tui.js` to a stable local path, for example `~/.local/share/opencode-global-sessions/tui.js`.
4. Point `tui.jsonc` at that local file, or at `{env:SESH_TUI_PLUGIN}`.

Do not point `tui.jsonc` at a raw `tui.js` GitHub URL. Use a local file path or an npm-compatible tarball URL.

### Future option: npm package

If this project is published as an npm package later, the install could become:

```json
{
  "plugin": ["opencode-global-sessions"]
}
```

OpenCode detects this package as a TUI plugin through `exports["./tui"]`.

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
| `list [n]`       | List n recent non-subagent sessions (default: 10). Add `--json` for machine-readable output. |
| `search <query>` | Global search across titles, directories, prompts, and responses |
| `show <id>`      | Show full session details             |
| `log <id>`       | Show user + assistant text log        |
| `prompts <id>`   | Show user prompts only                |
| `resume <id>`    | Print `opencode -s <id>`              |
| `files <id>`     | List files touched in a session       |
| `today`          | Sessions from the last 24 hours       |
| `stats`          | Aggregate session statistics          |
| `config`         | Show configuration and environment    |

### Search options

| Option           | Description                                   |
| ---------------- | --------------------------------------------- |
| `--content`      | Search message content too (default; kept for compatibility) |
| `--since <date>` | Filter by start date (ISO 8601 or `7d`)       |
| `--until <date>` | Filter by end date                            |
| `--limit <n>`    | Max results (default: 20)                     |
| `--fuzzy`        | Broader substring matching                    |
| `--json`         | Machine-readable JSON output (pipe to jq/fzf) |
| `--verbose`      | Include OpenCode subagent sessions            |

### Log/prompts options

| Option        | Description                  |
| ------------- | ---------------------------- |
| `--limit <n>` | Max messages (default: 50)   |
| `--full`      | Show full message text (default; kept for compatibility) |

### Subagent sessions

OpenCode stores subagent runs as normal sessions, usually with titles like `Review TUI plan (@explore subagent)`. These are useful for debugging but noisy for normal global session search.

By default, discovery commands hide subagent sessions:

- `sesh list`
- `sesh search <query>`
- `sesh today`
- `sesh stats`
- the native TUI picker (`/sessions-global`)

Use `--verbose` when you want to include them:

```bash
sesh list --verbose
sesh search tui --verbose
sesh today --verbose
sesh stats --verbose
```

Direct session commands still work with any session ID, including subagent IDs:

```bash
sesh show ses_xxxxxxxxxxxxxxxxxxxx
sesh log ses_xxxxxxxxxxxxxxxxxxxx
```

### Examples

```bash
sesh search justfile
sesh search justfile --since 7d
sesh search justfile --json | jq '.[].title'
sesh list 25 --json | jq '.[].id'
sesh list --verbose
sesh search shell --fuzzy
sesh search tui --verbose
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

OpenCode stores session metadata in `session`, message metadata in `message`, and actual text content in `part.data` rows where `type = "text"`. Commands such as `search`, `show`, `log`, and `prompts` join `message` with `part` so they show real prompt/response text instead of metadata-only placeholders.

OpenCode also records subagent activity as sessions. `sesh` hides those from discovery commands by default and includes them with `--verbose`.

## Limitations

The OpenCode database has a read-only schema — sesh cannot change what's stored.

- **Plain text is stored in `part.data`.** `sesh` reads text parts for prompts/responses. Non-text parts may contain tool metadata, reasoning, or attachments and are intentionally not expanded in the simple log view.
- **Tool output is not a full terminal transcript.** OpenCode stores structured parts and message metadata, not necessarily every rendered byte you saw in the TUI.
- **Dialog width is capped by terminal width.** The TUI plugin requests OpenCode's widest public dialog size (`xlarge`), but OpenCode caps dialogs at the current terminal width.
- **Resume is command-only.** `sesh resume <id>` prints `opencode -s <id>` so you can run it from any directory.

## License

[MIT LICENSE](LICENSE)
