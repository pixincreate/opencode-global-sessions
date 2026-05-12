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
| OpenCode | `/sessions-global`                 |
| OpenCode | `@sessions-global search keywatch` |

## Installation

### Terminal CLI (Recommended)

Download the `sesh` script and install it to your PATH:

```bash
# Download sesh
curl -fsSL https://raw.githubusercontent.com/pixincreate/opencode-global-sessions/master/sesh > sesh

# Install to PATH (assumes ~/.local/bin is in your PATH)
chmod +x sesh
cp sesh ~/.local/bin/

# Verify it works
sesh list
```

### OpenCode Plugin (Optional)

If you want to use `/sessions-global` from within OpenCode, you need to build the plugin:

```bash
git clone https://github.com/pixincreate/opencode-global-sessions.git
cd opencode-global-sessions
npm install && npm run build
cp sesh ~/.local/bin/
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

**Note:** OpenCode plugins cannot render popups or interactive UI. The `/sessions-global` command returns plain text output, just like running `sesh` from terminal.

## Usage

| Command          | Description                           |
| ---------------- | ------------------------------------- |
| `list [n]`       | List n recent sessions (default: 10)  |
| `search <query>` | Search sessions by title or directory |
| `show <id>`      | Show details for a specific session   |
| `today`          | List sessions from the last 24 hours  |

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

## License

[MIT LICENSE](LICENSE)
