#!/bin/zsh
set -euo pipefail

version=${1:?Usage: Scripts/package-direct-dmg.sh VERSION APP_PATH OUTPUT_DMG}
app=${2:?Usage: Scripts/package-direct-dmg.sh VERSION APP_PATH OUTPUT_DMG}
output=${3:?Usage: Scripts/package-direct-dmg.sh VERSION APP_PATH OUTPUT_DMG}

[[ "$version" =~ '^[0-9]+\.[0-9]+\.[0-9]+$' ]] || { echo "Invalid version: $version" >&2; exit 64; }
[[ -d "$app" && -f "$app/Contents/Info.plist" ]] || { echo "Missing app: $app" >&2; exit 66; }
[[ ! -e "$output" ]] || { echo "Output already exists: $output" >&2; exit 73; }

actual_version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")
[[ "$actual_version" == "$version" ]] || { echo "App version $actual_version does not match $version" >&2; exit 65; }
codesign --verify --deep --strict --verbose=2 "$app"

staging_root=$(mktemp -d /private/tmp/drawstate-dmg.XXXXXX)
trap 'rm -rf "$staging_root"' EXIT
mkdir -p "$staging_root/contents" "${output:h}"
ditto --norsrc --noextattr "$app" "$staging_root/contents/Drawstate.app"
ln -s /Applications "$staging_root/contents/Applications"
codesign --verify --deep --strict --verbose=2 "$staging_root/contents/Drawstate.app"

temporary_dmg="$staging_root/Drawstate-$version.dmg"
hdiutil create -quiet -volname "Drawstate $version" -srcfolder "$staging_root/contents" -format UDZO "$temporary_dmg"
hdiutil verify -quiet "$temporary_dmg"
ditto --norsrc --noextattr "$temporary_dmg" "$output"
hdiutil verify -quiet "$output"
echo "$output"
