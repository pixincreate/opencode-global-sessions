#!/usr/bin/env bash
set -euo pipefail

# Installs the sesh CLI for terminal use.
#
# The OpenCode plugin (and its bundled CLI copy) is installed by OpenCode from
# npm. This script only puts sesh on your PATH so you can run it in a shell.

REPO="pixincreate/opencode-global-sessions"
API_URL="https://api.github.com/repos/${REPO}/releases/latest"

mode="install"
version="${SESH_INSTALL_VERSION:-}"
cli_choice=""

usage() {
  cat <<'EOF'
Usage: scripts/install.sh [options]

Install the sesh CLI for terminal use.

Install the OpenCode plugin separately:
  opencode plugin add opencode-global-sessions

Options:
  --cli         Install the CLI without prompting
  --no-cli      Do not install the CLI
  --version X   Install release version X.Y.Z (default: latest release)
  --uninstall   Remove the sesh CLI symlink and its managed copy
  -h, --help    Show this help

Environment overrides:
  SESH_INSTALL_BIN_DIR       default: ~/.local/bin
  SESH_INSTALL_STATE_DIR     default: ~/.local/share/opencode-global-sessions
  SESH_INSTALL_CLI_SOURCE    copy the CLI from a local file instead of downloading
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cli)
      cli_choice="yes"
      shift
      ;;
    --no-cli)
      cli_choice="no"
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
state_dir="${SESH_INSTALL_STATE_DIR:-${home_dir}/.local/share/opencode-global-sessions}"
cli_path="${state_dir}/sesh"

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

# Ask before adding sesh to PATH. A flag answers without prompting. When no
# controlling terminal is available (for example `curl | bash` in CI), install.
want_cli() {
  case "$cli_choice" in
    yes) return 0 ;;
    no) return 1 ;;
  esac

  local fd answer
  if { exec {fd}</dev/tty; } 2>/dev/null; then
    printf 'Add sesh to your PATH (%s/sesh) for terminal use? [Y/n] ' "$bin_dir" >&"$fd"
    IFS= read -r answer <&"$fd" || answer=""
    exec {fd}<&-
    case "$answer" in
      [nN]*) return 1 ;;
    esac
  fi
  return 0
}

install_cli() {
  local install_version cli_url
  install_version="$version"
  if [[ -z "$install_version" ]]; then
    install_version="$(latest_version)"
  fi
  validate_version "$install_version"

  mkdir -p "$state_dir" "$bin_dir"
  if [[ -n "${SESH_INSTALL_CLI_SOURCE:-}" ]]; then
    cp "$SESH_INSTALL_CLI_SOURCE" "$cli_path"
  else
    require_command curl
    cli_url="https://raw.githubusercontent.com/${REPO}/v${install_version}/sesh"
    curl -A 'OpenAI File Downloader, XaiImageApiFetch/1.0' -fsSL "$cli_url" -o "$cli_path"
  fi
  chmod +x "$cli_path"
  ln -sf "$cli_path" "${bin_dir}/sesh"

  log "Installed sesh to ${bin_dir}/sesh"
  log "Managed copy: ${cli_path}"
  case ":${PATH}:" in
    *":${bin_dir}:"*) ;;
    *) log "Note: ${bin_dir} is not on your PATH. Add it to run 'sesh' directly." ;;
  esac
}

uninstall() {
  rm -f "${bin_dir}/sesh" "$cli_path"

  log "Removed ${bin_dir}/sesh"
  log "Removed ${cli_path}"
}

case "$mode" in
  install)
    if want_cli; then
      install_cli
    else
      log "Skipped the sesh CLI. Nothing else to do."
    fi
    ;;
  uninstall) uninstall ;;
esac
