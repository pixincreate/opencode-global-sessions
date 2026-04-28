# opencode-global-sessions - Global Session Search for OpenCode

List and search OpenCode sessions across **ALL directories**.

## Use Case

You work on multiple projects with OpenCode. Sometimes you start a session in project A, then switch to project B, then back to A. Later, you want to find that session you were working on 3 days ago - but you can't remember which directory it was in.

**Problem:** OpenCode's `/sessions` only shows sessions from the **current directory**.

**Solution:** This tool shows sessions from **ALL directories** globally.

## Quick Use

| Where    | Command                            |
| -------- | ---------------------------------- |
| Terminal | `~/path/to/sesh list`              |
| OpenCode | `/sessions-global`                 |
| OpenCode | `@sessions-global search keywatch` |

## How It Works

```
sesh (bash) ──> SQLite DB ──> Plugin ──> OpenCode
```

- **Bash CLI (`sesh`)**: Queries `~/.local/share/opencode/opencode.db` directly
- **Plugin**: Spawns bash CLI via Node's `execSync`
- **Slash**: `/sessions-global` invokes the plugin

## Commands

| Command          | Description                          |
| ---------------- | ------------------------------------ |
| `list [n]`       | List n recent sessions (default: 10) |
| `search <query>` | Search by title/directory            |
| `show <id>`      | Show session details                 |
| `today`          | Sessions from today                  |

## Why No TUI?

`/sessions` shows a clickable popup. `/sessions-global` returns text only.

**Reason:** OpenCode plugins cannot create TUI/popups. This is a platform limitation, not this tool's limitation.

## Installation

### As OpenCode Plugin

```json
// ~/.config/opencode/opencode.jsonc
{
  "plugin": ["/path/to/sesh"],
  "command": {
    "sessions-global": {
      "description": "List sessions from ALL directories",
      "template": "sessions-global list"
    }
  }
}
```

### As Terminal CLI

```bash
# Add to PATH
export PATH="$HOME/path/to:$PATH"

# Use
sesh list
sesh search keywatch
```

## Database

Reads from: `~/.local/share/opencode/opencode.db`

## License

MIT - See LICENSE file
