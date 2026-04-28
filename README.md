# opencode-global-sessions

Global session search for OpenCode. Query sessions across all directories, not just the current one.

## Description

OpenCode's built-in session search only shows sessions from the current working directory. This tool queries the global SQLite database directly, allowing you to find sessions from any project without switching directories.

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
