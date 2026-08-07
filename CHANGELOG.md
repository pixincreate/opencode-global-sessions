# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

## [1.0.3] - 2026-08-07

### Added

- `updated` (last-updated) column in `sesh search` and `sesh today` output

### Changed

- `sesh today` now lists sessions active in the last 24 hours (filtered by last update time) instead of only sessions created in that window, so resumed sessions appear

## [1.0.1] - 2026-07-08

### Added

- `sesh move <session-id> <target-project-dir>` to reclassify a session into an existing OpenCode project from the CLI
  - Defaults to a dry run that previews the current and target project without writing
  - `--apply` creates a SQLite backup and updates exactly one existing session row
  - Rejects unknown sessions, unknown target projects, duplicate project worktrees, conflicting flags, unsupported schemas, and no-op moves
- One-line installer support for installing both the `sesh` CLI and the OpenCode TUI plugin from the latest GitHub release
- Installer workflow coverage for versioned installs, clone-mode development installs, and uninstall paths
- `.omo/` ignore rule for local agent state

### Changed

- README now documents the move command, the dry-run/apply workflow, and the fact that `sesh move ... --apply` is the only write-capable CLI path
- The OpenCode database notes now describe the `project` table and clarify that session moves use a normal SQLite `UPDATE`, not a schema migration
- Release metadata now points at package version `1.0.1`

### Fixed

- Move backups now use SQLite `VACUUM INTO` instead of copying the database file directly, so backups remain valid for WAL-mode SQLite databases
- Move E2E coverage now verifies that backups are readable and contain the pre-move session row

## [1.0.0] - 2026-07-03

### Added

- Initial `sesh` CLI for finding OpenCode sessions across every project on the machine
- Global session listing with JSON output for scripting, `jq`, and picker integrations
- Session search across titles, directories, prompts, and assistant text responses
- Search filters for fuzzy matching, date ranges, result limits, JSON output, and verbose subagent inclusion
- `sesh show <id>` for full session details, message summaries, token counts, costs, and touched files
- `sesh log <id>` and `sesh prompts <id>` for reading conversation text from a session
- `sesh files <id>` to list files touched in a session
- `sesh resume <id>` to print the `opencode -s <id>` resume command
- `sesh today`, `sesh stats`, and `sesh config` helper commands
- Native OpenCode TUI plugin with `/sessions-global` for opening recent global sessions from a picker
- Default filtering of OpenCode subagent sessions from discovery commands, with `--verbose` to include them
- End-to-end CLI and TUI coverage against temporary SQLite databases
- ShellCheck, build, and test CI coverage
- GitHub release workflow that builds and attaches the npm plugin tarball
- Release helper script for version bumps, checks, tagging, and pushing releases
- Dependabot configuration for dependency updates

### Changed

- Renamed the package to `opencode-global-sessions`
- Replaced Bun-specific execution with Node `child_process` usage in the plugin
- Removed compiled `dist/` files from git tracking; release packaging now builds generated output
- Simplified and reorganized README installation, usage, limitations, and development documentation
- Reformatted README tables and TUI plugin source for consistency
- Upgraded `esbuild` from `0.28.0` to `0.28.1`

### Fixed

- `--content` search now queries `part.data`, where OpenCode stores actual prompt and response text
- Help and terminal output no longer include ANSI color codes that rendered poorly in some terminals
- Path handling and security/error handling were hardened during the project cleanup
