#!/usr/bin/env bash
#
# Cuts a release in one command: bumps the version in pubspec.yaml, commits it,
# creates the git tag, and pushes. Pushing the tag triggers the GitHub Actions
# release workflow, which builds the signed APK, generates latest.json, and
# publishes the GitHub Release that the in-app Changelog and updater read.
#
# Usage:
#   ./scripts/cut_release.sh 2.1.9        # versionName; build number auto-increments
#   ./scripts/cut_release.sh 2.1.9 5      # explicit versionName + build number
#
# You commit your feature work normally as often as you like — NOTHING is
# released until you run this. A release == one pushed tag, not one push.

set -euo pipefail
cd "$(dirname "$0")/.."

red()   { printf '\033[31m%s\033[0m\n' "$1"; }
green() { printf '\033[32m%s\033[0m\n' "$1"; }

VERSION_NAME="${1:-}"
[ -n "$VERSION_NAME" ] || { red "Usage: $0 <versionName> [buildNumber]   e.g. $0 2.1.9"; exit 1; }

# Current "version: X.Y.Z+CODE" line from pubspec.yaml.
CURRENT="$(grep -E '^version:' pubspec.yaml | head -1 | sed 's/version:[[:space:]]*//')"
CURRENT_CODE="${CURRENT##*+}"
BUILD_NUMBER="${2:-$((CURRENT_CODE + 1))}"
NEW_VERSION="${VERSION_NAME}+${BUILD_NUMBER}"
TAG="v${VERSION_NAME}"

echo "Current : $CURRENT"
echo "New     : $NEW_VERSION   (tag $TAG)"

# Guard: clean tree and tag not already used.
if ! git diff --quiet || ! git diff --cached --quiet; then
  red "Working tree has uncommitted changes. Commit or stash them first."; exit 1
fi
if git rev-parse "$TAG" >/dev/null 2>&1; then
  red "Tag $TAG already exists. Pick a new version."; exit 1
fi

# Bump pubspec.yaml in place.
sed -i.bak -E "s/^version:.*/version: ${NEW_VERSION}/" pubspec.yaml && rm -f pubspec.yaml.bak

git add pubspec.yaml
git commit -m "chore(release): ${TAG}"
git tag "$TAG"

BRANCH="$(git rev-parse --abbrev-ref HEAD)"
git push origin "$BRANCH"
git push origin "$TAG"

green "Pushed $TAG. The release workflow is now building."
echo "Watch it:   gh run watch     (or the Actions tab on GitHub)"
echo "When green, the new version appears in the app's Project > Changelog."
