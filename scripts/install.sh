#!/usr/bin/env bash
set -euo pipefail

REPO="pixincreate/opencode-global-sessions"
REPO_URL_DEFAULT="https://github.com/${REPO}.git"
API_URL="https://api.github.com/repos/${REPO}/releases/latest"
MANAGED_START="opencode-global-sessions:start"
MANAGED_END="opencode-global-sessions:end"

mode="release"
version="${SESH_INSTALL_VERSION:-}"
opencode_version=""

usage() {
  cat <<'EOF'
Usage: scripts/install.sh [options]

Install sesh CLI and the OpenCode CLI plugin.

Supports OpenCode v1 and v2.

Options:
  --clone       Clone/build locally and symlink sesh + dist/tui.js
  --uninstall   Remove sesh and the managed OpenCode plugin entry
  --version X   Install release version X.Y.Z (default: latest release)
  --opencode-version 1|2  Select the host (default: detect opencode --version)
  -h, --help    Show this help

Environment overrides:
  SESH_INSTALL_BIN_DIR       default: ~/.local/bin
  SESH_INSTALL_CONFIG        override the selected host's config path
  SESH_INSTALL_REPO_DIR      default: ~/.local/share/opencode-global-sessions/repo
  SESH_INSTALL_REPO_URL      default: https://github.com/pixincreate/opencode-global-sessions.git
  SESH_INSTALL_CLI_SOURCE    copy CLI from local file instead of downloading
  SESH_INSTALL_PLUGIN_SPEC   plugin package spec to write instead of the npm package
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
    --opencode-version)
      opencode_version="${2:-}"
      [[ "$opencode_version" == 1 || "$opencode_version" == 2 ]] || { echo "Error: --opencode-version requires 1 or 2" >&2; exit 1; }
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
if [[ -z "$opencode_version" ]]; then
  detected="$(opencode --version 2>/dev/null || true)"
  detected="${detected#opencode }"
  if [[ "$detected" =~ ^v?([12])\.[0-9]+\.[0-9]+ ]]; then
    opencode_version="${BASH_REMATCH[1]}"
  else
    echo "Error: cannot detect OpenCode version. Pass --opencode-version 1 or 2." >&2
    exit 1
  fi
fi
config_name="tui.jsonc"
config_key="plugin"
if [[ "$opencode_version" == 2 ]]; then config_name="cli.json"; config_key="plugins"; fi
bin_dir="${SESH_INSTALL_BIN_DIR:-${home_dir}/.local/bin}"
config_file="${SESH_INSTALL_CONFIG:-${XDG_CONFIG_HOME:-${home_dir}/.config}/opencode/${config_name}}"
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
  curl -A 'OpenAI File Downloader, XaiImageApiFetch/1.0' -fsSL "$API_URL" \
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
  spec="${spec//\\/\\\\}"
  spec="${spec//\"/\\\"}"
  spec="${spec//$'\n'/\\n}"
  spec="${spec//$'\r'/\\r}"
  spec="${spec//$'\t'/\\t}"
  local entry="{ \"package\": \"${spec}\", \"options\": { \"limit\": 50 } }"
  if [[ "$opencode_version" == 1 ]]; then entry="[\"${spec}\", { \"limit\": 50 }]"; fi
  cat <<EOF
    // ${MANAGED_START}
    ${entry},
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
  "${config_key}": [
$(plugin_block "$spec")
  ]
}
EOF
    return
  fi

  local array_pattern="^[[:space:]]*(\\{[[:space:]]*)?\"${config_key}\"[[:space:]]*:[[:space:]]*\\["
  # Do not edit block-comment layouts with the line-oriented writer.
  if grep -Fq '/*' "$config_file"; then
    echo "Error: unsupported config layout. Remove block comments before running the installer." >&2
    return 1
  fi
  if ! grep -Eq "$array_pattern" "$config_file" &&
     ! grep -Eq '^[[:space:]]*\{[[:space:]]*\}[[:space:]]*$' "$config_file"; then
    if awk -v key="$config_key" '!/^[[:space:]]*\/\// && $0 ~ "\"" key "\"[[:space:]]*:" { found=1 } END { exit !found }' "$config_file" ||
       ! grep -Eq '^[[:space:]]*\{[[:space:]]*$' "$config_file"; then
      echo "Error: unsupported config layout. Add a ${config_key} array before running the installer." >&2
      return 1
    fi
  fi
  strip_managed_plugin "$config_file"
  tmp="$(mktemp)"
  block_file="$(mktemp)"
  plugin_block "$spec" >"$block_file"

  if grep -Eq "$array_pattern" "$config_file"; then
    awk -v block_file="$block_file" -v key="$config_key" '
      inserted == 0 && $0 ~ "^[[:space:]]*(\\{[[:space:]]*)?\"" key "\"[[:space:]]*:[[:space:]]*\\[" {
        match($0, "\"" key "\"[[:space:]]*:[[:space:]]*\\[")
        boundary = RSTART + RLENGTH - 1
        print substr($0, 1, boundary)
        while ((getline line < block_file) > 0) print line
        close(block_file)
        print substr($0, boundary + 1)
        inserted = 1
        next
      }
      { print }
    ' "$config_file" >"$tmp"
  elif grep -Eq '^[[:space:]]*\{[[:space:]]*\}[[:space:]]*$' "$config_file"; then
    cat >"$tmp" <<EOF
{
  "${config_key}": [
$(plugin_block "$spec")
  ]
}
EOF
  else
    awk -v block_file="$block_file" -v key="$config_key" '
      inserted == 0 && /^[[:space:]]*\{/ {
        print
        print "  \"" key "\": ["
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
    curl -A 'OpenAI File Downloader, XaiImageApiFetch/1.0' -fsSL "$cli_url" -o "${bin_dir}/sesh"
  fi
  chmod +x "${bin_dir}/sesh"

  plugin_spec="${SESH_INSTALL_PLUGIN_SPEC:-opencode-global-sessions@${install_version}}"
  write_plugin_config "$plugin_spec"

  log "Installed sesh to ${bin_dir}/sesh"
  log "Configured OpenCode CLI plugin in ${config_file}"
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
  if [[ "$opencode_version" == 2 ]]; then write_plugin_config "${repo_dir}/dist"; else write_plugin_config "${repo_dir}/dist/tui.js"; fi

  log "Symlinked sesh to ${bin_dir}/sesh"
  log "Configured local OpenCode CLI plugin in ${config_file}"
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
  log "Removed managed OpenCode CLI plugin entry from ${config_file}"
}

case "$mode" in
  release) install_release ;;
  clone) install_clone ;;
  uninstall) uninstall ;;
esac
