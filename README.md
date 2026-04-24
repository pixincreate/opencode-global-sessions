# sesh - Global Session Search

Quick & memorable session search for OpenCode CLI.

## Quick Start

```bash
# Find your session
sesh list
sesh search keywatch
sesh today
```

## Installation

### As CLI (recommended)

```bash
export PATH="$HOME/dev/forge/scripts/sesh:$PATH"
sesh list
```

### As OpenCode Plugin

Add to your opencode config:

```json
// ~/.config/opencode/opencode.json
{
  "plugins": {
    "sesh": "./sesh"
  }
}
```

Then use in OpenCode:
```
@sesh list
@sesh search keywatch
```

## Commands

| Command | Description |
|--------|-------------|
| `sesh list [n]` | List n recent sessions (default: 10) |
| `sesh search <query>` | Search sessions by title/directory |
| `sesh dir <path>` | Find sessions for directory |
| `sesh today` | Sessions from today |
| `sesh range <days>` | Sessions from last N days |
| `sesh show <id>` | Show session details |

## Examples

```bash
# List 20 recent sessions
sesh list 20

# Search for keywatch sessions
sesh search keywatch

# Find sessions for a project
sesh dir ~/projects/myapp

# Today's sessions
sesh today

# Last 7 days
sesh range 7

# Show session details
sesh show ses_24505ac96ffemL7ijB336Ccrt0
```

## Database

Reads from: `~/.local/share/opencode/opencode.db`

## Notes

- Only your prompts are stored (not AI responses)
- Sessions auto-purge after some time
- Use `prompt-history.jsonl` for full prompt history:
  ```bash
  cat ~/.local/state/opencode/prompt-history.jsonl
  ```
