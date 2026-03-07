#!/usr/bin/env bash
set -euo pipefail

PLUGIN_JSON=".claude-plugin/plugin.json"

current=$(jq -r .version "$PLUGIN_JSON")
IFS='.' read -r major minor patch <<< "$current"

# Find the range of commits to inspect
# Look for the last version-bump commit or last tag
last_bump=$(git log --oneline --format="%H %s" | grep "^[^ ]* chore: bump version" | head -1 | awk '{print $1}' || true)
last_tag=$(git describe --tags --abbrev=0 2>/dev/null || true)

if [[ -n "$last_bump" ]]; then
  range="${last_bump}..HEAD"
elif [[ -n "$last_tag" ]]; then
  range="${last_tag}..HEAD"
else
  range="HEAD"
fi

# Collect commit messages in the range
if [[ "$range" == "HEAD" ]]; then
  messages=$(git log --format="%s%n%b" HEAD)
else
  messages=$(git log --format="%s%n%b" "$range")
fi

bump="patch"

while IFS= read -r line; do
  if [[ "$line" =~ ^feat!: ]] || [[ "$line" == *"BREAKING CHANGE"* ]]; then
    bump="major"
    break
  elif [[ "$line" =~ ^feat: ]]; then
    if [[ "$bump" != "major" ]]; then
      bump="minor"
    fi
  fi
done <<< "$messages"

case "$bump" in
  major) major=$((major + 1)); minor=0; patch=0 ;;
  minor) minor=$((minor + 1)); patch=0 ;;
  patch) patch=$((patch + 1)) ;;
esac

new_version="${major}.${minor}.${patch}"

if [[ "$new_version" == "$current" ]]; then
  echo "No version change needed (still $current)" >&2
  exit 0
fi

echo "Bumping $current → $new_version ($bump)" >&2
tmp=$(mktemp)
jq --arg v "$new_version" '.version = $v' "$PLUGIN_JSON" > "$tmp"
mv "$tmp" "$PLUGIN_JSON"
echo "$new_version"
