#!/usr/bin/env bash
set -euo pipefail

REPO="pixincreate/opencode-global-sessions"
REPO_URL_DEFAULT="https://github.com/${REPO}.git"
API_URL="https://api.github.com/repos/${REPO}/releases/latest"
MANAGED_START="opencode-global-sessions:start"
MANAGED_END="opencode-global-sessions:end"

mode="release"
version="${SESH_INSTALL_VERSION:-}"

usage() {
  cat <<'EOF'
Usage: scripts/install.sh [options]

Install sesh CLI and the OpenCode TUI plugin.

Options:
  --clone       Clone/build locally and symlink sesh + dist/tui.js
  --uninstall   Remove sesh and the managed OpenCode plugin entry
  --version X   Install release version X.Y.Z (default: latest release)
  -h, --help    Show this help

Environment overrides:
  SESH_INSTALL_BIN_DIR       default: ~/.local/bin
  SESH_INSTALL_CONFIG        default: ~/.config/opencode/tui.jsonc
  SESH_INSTALL_REPO_DIR      default: ~/.local/share/opencode-global-sessions/repo
  SESH_INSTALL_REPO_URL      default: https://github.com/pixincreate/opencode-global-sessions.git
  SESH_INSTALL_CLI_SOURCE    copy CLI from local file instead of downloading
  SESH_INSTALL_PLUGIN_SPEC   plugin spec to write instead of release tarball URL
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --clone)
      mode="clone"
      shift
      ;;
    --uninstall)
      mode="uninstall"
      shift
      ;;
    --version)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --version requires a value" >&2
        exit 1
      fi
      version="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Error: unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

home_dir="${HOME:?HOME is required}"
bin_dir="${SESH_INSTALL_BIN_DIR:-${home_dir}/.local/bin}"
config_file="${SESH_INSTALL_CONFIG:-${home_dir}/.config/opencode/tui.jsonc}"
state_dir="${SESH_INSTALL_STATE_DIR:-${home_dir}/.local/share/opencode-global-sessions}"
repo_dir="${SESH_INSTALL_REPO_DIR:-${state_dir}/repo}"
repo_url="${SESH_INSTALL_REPO_URL:-$REPO_URL_DEFAULT}"

log() {
  printf '%s\n' "$*"
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Error: required command not found: $1" >&2
    exit 1
  fi
}

latest_version() {
  require_command curl
  curl -fsSL "$API_URL" \
    | tr ',' '\n' \
    | awk -F'"' '/"tag_name"/ { print $4; exit }' \
    | sed 's/^v//'
}

validate_version() {
  if ! [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$ ]]; then
    echo "Error: version must be semver, for example 1.0.0" >&2
    exit 1
  fi
}

plugin_block() {
  local spec="$1"
  cat <<EOF
    // ${MANAGED_START}
    ["${spec}", { "limit": 50 }],
    // ${MANAGED_END}
EOF
}

strip_managed_plugin() {
  local file="$1"
  local tmp
  tmp="$(mktemp)"
  awk -v start="$MANAGED_START" -v end="$MANAGED_END" '
    index($0, start) { skip = 1; next }
    index($0, end) { skip = 0; next }
    !skip { print }
  ' "$file" >"$tmp"
  mv "$tmp" "$file"
}

write_plugin_config() {
  local spec="$1"
  local dir tmp block_file
  dir="$(dirname "$config_file")"
  mkdir -p "$dir"

  if [[ ! -f "$config_file" ]]; then
    cat >"$config_file" <<EOF
{
  "plugin": [
$(plugin_block "$spec")
  ]
}
EOF
    return
  fi

  strip_managed_plugin "$config_file"
  tmp="$(mktemp)"
  block_file="$(mktemp)"
  plugin_block "$spec" >"$block_file"

  if grep -Eq '"plugin"[[:space:]]*:[[:space:]]*\[[[:space:]]*\]' "$config_file"; then
    awk -v block_file="$block_file" '
      /"plugin"[[:space:]]*:[[:space:]]*\[[[:space:]]*\]/ {
        sub(/\[[[:space:]]*\]/, "[")
        print
        while ((getline line < block_file) > 0) print line
        close(block_file)
        print "  ]"
        next
      }
      { print }
    ' "$config_file" >"$tmp"
  elif grep -Eq '"plugin"[[:space:]]*:[[:space:]]*\[' "$config_file"; then
    awk -v block_file="$block_file" '
      inserted == 0 && /"plugin"[[:space:]]*:[[:space:]]*\[/ {
        print
        while ((getline line < block_file) > 0) print line
        close(block_file)
        inserted = 1
        next
      }
      { print }
    ' "$config_file" >"$tmp"
  elif grep -Eq '^[[:space:]]*\{[[:space:]]*\}[[:space:]]*$' "$config_file"; then
    cat >"$tmp" <<EOF
{
  "plugin": [
$(plugin_block "$spec")
  ]
}
EOF
  else
    awk -v block_file="$block_file" '
      inserted == 0 && /^[[:space:]]*\{/ {
        print
        print "  \"plugin\": ["
        while ((getline line < block_file) > 0) print line
        close(block_file)
        print "  ],"
        inserted = 1
        next
      }
      { print }
    ' "$config_file" >"$tmp"
  fi

  mv "$tmp" "$config_file"
  rm -f "$block_file"
}

install_release() {
  local install_version cli_url plugin_spec
  install_version="$version"
  if [[ -z "$install_version" ]]; then
    install_version="$(latest_version)"
  fi
  validate_version "$install_version"

  mkdir -p "$bin_dir"
  if [[ -n "${SESH_INSTALL_CLI_SOURCE:-}" ]]; then
    cp "$SESH_INSTALL_CLI_SOURCE" "${bin_dir}/sesh"
  else
    require_command curl
    cli_url="https://raw.githubusercontent.com/${REPO}/v${install_version}/sesh"
    curl -fsSL "$cli_url" -o "${bin_dir}/sesh"
  fi
  chmod +x "${bin_dir}/sesh"

  plugin_spec="${SESH_INSTALL_PLUGIN_SPEC:-https://github.com/${REPO}/releases/download/v${install_version}/opencode-global-sessions-${install_version}.tgz}"
  write_plugin_config "$plugin_spec"

  log "Installed sesh to ${bin_dir}/sesh"
  log "Configured OpenCode TUI plugin in ${config_file}"
}

install_clone() {
  require_command git
  require_command npm

  if [[ -d "$repo_dir/.git" ]]; then
    git -C "$repo_dir" pull --ff-only
  else
    mkdir -p "$(dirname "$repo_dir")"
    git clone "$repo_url" "$repo_dir"
  fi

  (cd "$repo_dir" && npm install && npm run build)

  mkdir -p "$bin_dir"
  ln -sf "${repo_dir}/sesh" "${bin_dir}/sesh"
  write_plugin_config "${repo_dir}/dist/tui.js"

  log "Symlinked sesh to ${bin_dir}/sesh"
  log "Configured local OpenCode TUI plugin in ${config_file}"
}

uninstall() {
  rm -f "${bin_dir}/sesh"

  if [[ -f "$config_file" ]]; then
    strip_managed_plugin "$config_file"
  fi

  case "$repo_dir" in
    "$state_dir"/*)
      rm -rf "$repo_dir"
      ;;
  esac

  log "Removed sesh from ${bin_dir}/sesh"
  log "Removed managed OpenCode TUI plugin entry from ${config_file}"
}

case "$mode" in
  release) install_release ;;
  clone) install_clone ;;
  uninstall) uninstall ;;
esac
