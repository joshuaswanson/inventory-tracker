#!/bin/bash
set -euo pipefail

version="${1:-}"
if [[ ! "$version" =~ ^[0-9]+(\.[0-9]+)+$ ]]; then
    echo "Usage: release.sh 1.1" >&2
    exit 1
fi

apple_dir="$(cd "$(dirname "$0")/.." && pwd)"
repo_dir="$(dirname "$apple_dir")"
project="$apple_dir/InventoryTracker.xcodeproj/project.pbxproj"
cd "$repo_dir"

if [ "$(git branch --show-current)" != main ] || [ -n "$(git status --porcelain)" ]; then
    echo "Release from main with everything committed." >&2
    exit 1
fi
git fetch --quiet origin
if [ "$(git rev-parse HEAD)" != "$(git rev-parse origin/main)" ]; then
    echo "main does not match GitHub. Push or pull first." >&2
    exit 1
fi
if gh release view "v$version" >/dev/null 2>&1; then
    echo "v$version already exists." >&2
    exit 1
fi

current="$(grep -m1 'MARKETING_VERSION' "$project" | sed -E 's/.*= (.*);/\1/')"
if [ "$current" != "$version" ]; then
    build="$(git rev-list --count HEAD)"
    sed -i '' -E "s/MARKETING_VERSION = .*;/MARKETING_VERSION = $version;/" "$project"
    sed -i '' -E "s/CURRENT_PROJECT_VERSION = .*;/CURRENT_PROJECT_VERSION = $build;/" "$project"
    git add "$project"
    git commit -q -m "Release $version"
    git push -q origin main
fi

"$apple_dir/packaging/make-dmg.sh"
asset="$repo_dir/dist/Inventory-Tracker-$version.dmg"
cp "$repo_dir/dist/Inventory Tracker.dmg" "$asset"

gh release create "v$version" "$asset#Inventory Tracker $version for Mac" \
    --target main \
    --title "Inventory Tracker $version" \
    --notes-file "$apple_dir/packaging/release-notes.md"
