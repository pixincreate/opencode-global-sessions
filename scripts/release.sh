#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/release.sh <version>

Example:
  scripts/release.sh 1.0.1

This updates package.json/package-lock.json when needed, runs checks, creates
tag v<version>, and pushes master plus the tag.
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

version="${1:-}"
if [[ -z "$version" ]]; then
  usage >&2
  exit 1
fi

if ! [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$ ]]; then
  echo "Error: version must be semver, for example 1.0.1" >&2
  exit 1
fi

branch="$(git branch --show-current)"
if [[ "$branch" != "master" ]]; then
  echo "Error: release from master, not ${branch}" >&2
  exit 1
fi

if [[ -n "$(git status --porcelain)" ]]; then
  echo "Error: working tree is not clean" >&2
  exit 1
fi

tag="v${version}"
if git rev-parse "$tag" >/dev/null 2>&1; then
  echo "Error: tag ${tag} already exists" >&2
  exit 1
fi

current_version="$(node -p "JSON.parse(require('fs').readFileSync('package.json', 'utf8')).version")"
if [[ "$current_version" != "$version" ]]; then
  npm version "$version" --no-git-tag-version
fi

npm run check
npm pack --dry-run

if ! git diff --quiet -- package.json package-lock.json; then
  git add package.json package-lock.json
  git commit -m "chore: release ${tag}"
fi

git tag -a "$tag" -m "opencode-global-sessions ${tag}"

echo "Created ${tag}. Pushing master and tag..."
git push origin master
git push origin "$tag"
