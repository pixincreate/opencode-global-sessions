# opencode-sesh - Global Session Search for OpenCode

List and search OpenCode sessions across ALL directories.

## Why This Exists

OpenCode's built-in `/sessions` command only shows sessions from the **current directory**. This tool lets you see sessions from ALL directories globally.

## How It Works

### Architecture

```
sesh/
├── sesh                    # Bash CLI (standalone terminal tool)
├── src/plugin/index.ts      # OpenCode plugin (spawns bash CLI)
└── dist/index.js           # Compiled plugin
```

1. **Bash CLI (`sesh`)**: Direct SQLite queries to `~/.local/share/opencode/opencode.db`
2. **Plugin (`sessions-global`)**: Spawns bash CLI via `Bun.spawn()` and returns output
3. **Slash Command (`/sessions-global`)**: Calls the plugin tool

### Usage

```bash
# Terminal
~/dev/forge/scripts/sesh/sesh list
~/dev/forge/scripts/sesh/sesh search keywatch

# In OpenCode
@sessions-global list
@sessions-global search keywatch
```

## Commands

| Command | Description |
|---------|-------------|
| `list [n]` | List n recent sessions (default: 10) |
| `search <query>` | Search by title/directory |
| `show <id>` | Show session details |
| `today` | Sessions from today |

## Drawbacks: Why `/sessions-global` != `/sessions`

**`/sessions` (built-in)**
- Shows TUI popup with clickable sessions
- Native OpenCode feature
- Only shows current directory

**`/sessions-global` (this tool)**
- Returns **text output** only
- Cannot create TUI popups
- Shows ALL directories

**Why?**
- OpenCode plugins **cannot** create TUI/popup interfaces
- Plugins can only return text or call tools
- The TUI popup is a built-in OpenCode feature, not extensible via plugins

This is a OpenCode platform limitation, not this tool's limitation.

## Installation

### As Plugin

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

### As CLI

```bash
# Add to PATH
export PATH="$HOME/dev/forge/scripts/sesh:$PATH"

# Or use full path
~/dev/forge/scripts/sesh/sesh list
```

## Database

Reads from: `~/.local/share/opencode/opencode.db`

## License

MIT License - See LICENSE file.

## Notes

- Sessions auto-purge after some time
- Only prompts are stored (not AI responses)
- For full prompt history: `cat ~/.local/state/opencode/prompt-history.jsonl`