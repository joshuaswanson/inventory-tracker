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

signing_key="$HOME/.config/inventory-tracker/sparkle-private-key"
if [ ! -f "$signing_key" ]; then
    echo "Missing the update signing key at $signing_key." >&2
    exit 1
fi

build="$(($(git rev-list --count HEAD) + 1))"
sed -i '' -E "s/MARKETING_VERSION = .*;/MARKETING_VERSION = $version;/" "$project"
sed -i '' -E "s/CURRENT_PROJECT_VERSION = .*;/CURRENT_PROJECT_VERSION = $build;/" "$project"
if [ -n "$(git status --porcelain)" ]; then
    git add "$project"
    git commit -q -m "Release $version"
    git push -q origin main
fi

"$apple_dir/packaging/make-dmg.sh"
asset="$repo_dir/dist/Inventory-Tracker-$version.dmg"
cp "$repo_dir/dist/Inventory Tracker.dmg" "$asset"

signature="$("$repo_dir/.build/packages/artifacts/sparkle/Sparkle/bin/sign_update" --ed-key-file "$signing_key" "$asset")"
appcast="$repo_dir/dist/appcast.xml"
cat > "$appcast" <<XML
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
    <channel>
        <title>Inventory Tracker</title>
        <item>
            <title>Version $version</title>
            <pubDate>$(date -R)</pubDate>
            <sparkle:version>$build</sparkle:version>
            <sparkle:shortVersionString>$version</sparkle:shortVersionString>
            <sparkle:minimumSystemVersion>15.0</sparkle:minimumSystemVersion>
            <enclosure url="https://github.com/joshuaswanson/inventory-tracker/releases/download/v$version/Inventory-Tracker-$version.dmg" type="application/octet-stream" $signature/>
        </item>
    </channel>
</rss>
XML

gh release create "v$version" "$asset#Inventory Tracker $version for Mac" "$appcast" \
    --target main \
    --title "Inventory Tracker $version" \
    --notes-file "$apple_dir/packaging/release-notes.md"
