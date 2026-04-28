# opencode-global-sessions

Global session search for OpenCode. Query sessions across all directories, not just the current one.

## Description

OpenCode's built-in session search only shows sessions from the current working directory. This tool queries the global SQLite database directly, allowing you to find sessions from any project without switching directories.

## Use Case

You work on multiple projects with OpenCode. Sometimes you start a session in project A, then switch to project B, then back to A. Later, you want to find that session you were working on 3 days ago - but you can't remember which directory it was in.

**Problem:** OpenCode's `/sessions` only shows sessions from the **current directory**.

**Solution:** This tool shows sessions from **ALL directories** globally.

## Quick Use

| Where | Command |
|--------|----------------------------------|
| Terminal | `~/path/to/sesh list` |
| OpenCode | `/sessions-global` |
| OpenCode | `@sessions-global search keywatch` |

## Quickstart

```bash
# List recent sessions
sesh list

# Search across all sessions
sesh search "my project"

# Show specific session
sesh show <session-id>

# Today's sessions
sesh today
```

## Usage

| Command | Description |
|---------|-------------|
| `list [n]` | List n recent sessions (default: 10) |
| `search <query>` | Search sessions by title or directory |
| `show <id>` | Show details for a specific session |
| `today` | List sessions from the last 24 hours |

## Installation

### Build from Source

```bash
git clone https://github.com/pixincreate/opencode-global-sessions.git
cd opencode-global-sessions
npm install && npm run build

# Optional: install CLI to PATH
cp sesh ~/.local/bin/
```

### OpenCode Plugin

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

### Configuration

Override defaults via environment variables:

```bash
export OPENCODE_DB="/custom/path/to/opencode.db"
export SESH_BIN="/custom/path/to/sesh"
```

## How It Works

```
OpenCode Plugin → Bash CLI → SQLite Database
```

The plugin spawns the bash CLI via `execSync`, which queries `~/.local/share/opencode/opencode.db` directly. Results are returned as plain text since OpenCode plugins cannot render interactive UI elements.

## Why No TUI?

OpenCode plugins operate in a restricted environment. They cannot create popups, clickable lists, or interactive elements. The `/sessions` command shows a TUI popup because it is a built-in platform feature. Third-party plugins are limited to text output only.

## License

[MIT LICENSE](LICENSE)
