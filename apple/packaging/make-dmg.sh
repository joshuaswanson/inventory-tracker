#!/bin/bash
set -euo pipefail

apple_dir="$(cd "$(dirname "$0")/.." && pwd)"
repo_dir="$(dirname "$apple_dir")"
build_dir="$(mktemp -d)"
output="$repo_dir/dist/Inventory Tracker.dmg"
trap 'rm -rf "$build_dir"' EXIT

xcodebuild -quiet \
    -project "$apple_dir/InventoryTracker.xcodeproj" \
    -scheme InventoryTracker \
    -configuration Release \
    -destination 'platform=macOS' \
    -derivedDataPath "$build_dir/derived" \
    -clonedSourcePackagesDirPath "$repo_dir/.build/packages" \
    build

app="$build_dir/derived/Build/Products/Release/Inventory Tracker.app"
mkdir -p "$repo_dir/dist"
rm -f "$output"

uvx dmgbuild \
    -s "$apple_dir/packaging/dmg-settings.py" \
    -D "app=$app" \
    -D "background=$apple_dir/packaging/dmg-background.png" \
    "Inventory Tracker" \
    "$output"

echo "$output"
