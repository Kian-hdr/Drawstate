#!/bin/zsh
set -euo pipefail

project_dir=${0:A:h:h}
version=${1:?Usage: Scripts/notarize-release.sh VERSION}
[[ "$version" =~ '^[0-9]+\.[0-9]+\.[0-9]+$' ]] || { echo "Invalid version: $version" >&2; exit 64; }
: "${DRAWSTATE_SIGNING_IDENTITY:?Set DRAWSTATE_SIGNING_IDENTITY}"

output_dir=${DRAWSTATE_RELEASE_OUTPUT_DIR:-"$project_dir/build"}
mkdir -p "$output_dir" "$HOME/Library/Caches/Drawstate"
for suffix in dmg dmg.sha256 zip zip.sha256; do
  [[ ! -e "$output_dir/Drawstate-$version.$suffix" ]] || {
    echo "Release output already exists: $output_dir/Drawstate-$version.$suffix" >&2
    exit 73
  }
done

notary_arguments=()
if [[ -n "${DRAWSTATE_NOTARY_PROFILE:-}" ]]; then
  notary_arguments+=(--keychain-profile "$DRAWSTATE_NOTARY_PROFILE")
else
  : "${APPLE_ID:?Set APPLE_ID or DRAWSTATE_NOTARY_PROFILE}"
  : "${APPLE_TEAM_ID:?Set APPLE_TEAM_ID or DRAWSTATE_NOTARY_PROFILE}"
  : "${APPLE_APP_SPECIFIC_PASSWORD:?Set APPLE_APP_SPECIFIC_PASSWORD or DRAWSTATE_NOTARY_PROFILE}"
  notary_arguments+=(--apple-id "$APPLE_ID" --team-id "$APPLE_TEAM_ID" --password "$APPLE_APP_SPECIFIC_PASSWORD")
fi

release_dir=$(mktemp -d /private/tmp/drawstate-release.XXXXXX)
evidence_dir=$(mktemp -d "$HOME/Library/Caches/Drawstate/release-$version.XXXXXX")
trap 'rm -rf "$release_dir"' EXIT
app="$release_dir/Drawstate.app"
initial_zip="$release_dir/Drawstate-$version-for-notary.zip"
final_zip="$release_dir/Drawstate-$version.zip"
dmg="$release_dir/Drawstate-$version.dmg"

DRAWSTATE_VERSION="$version" DRAWSTATE_OUTPUT_DIR="$release_dir" \
  "$project_dir/Scripts/package-app.sh" release direct
actual_version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")
[[ "$actual_version" == "$version" ]] || { echo "Built version $actual_version does not match $version" >&2; exit 65; }
codesign --verify --deep --strict --verbose=2 "$app"
ditto -c -k --keepParent --norsrc "$app" "$initial_zip"

xcrun notarytool submit "$initial_zip" "${notary_arguments[@]}" --wait --output-format json > "$evidence_dir/app-notary-result.json"
app_id=$(python3 -c 'import json,sys; p=json.load(open(sys.argv[1])); assert p.get("status")=="Accepted", p; print(p["id"])' "$evidence_dir/app-notary-result.json")
xcrun notarytool log "$app_id" "$evidence_dir/app-notary-log.json" "${notary_arguments[@]}"
xcrun stapler staple "$app"
xcrun stapler validate "$app"
spctl --assess --type execute --verbose=2 "$app"

ditto -c -k --keepParent --norsrc "$app" "$final_zip"
"$project_dir/Scripts/package-direct-dmg.sh" "$version" "$app" "$dmg"
xcrun notarytool submit "$dmg" "${notary_arguments[@]}" --wait --output-format json > "$evidence_dir/dmg-notary-result.json"
dmg_id=$(python3 -c 'import json,sys; p=json.load(open(sys.argv[1])); assert p.get("status")=="Accepted", p; print(p["id"])' "$evidence_dir/dmg-notary-result.json")
xcrun notarytool log "$dmg_id" "$evidence_dir/dmg-notary-log.json" "${notary_arguments[@]}"
xcrun stapler staple "$dmg"
xcrun stapler validate "$dmg"
hdiutil verify -quiet "$dmg"

ditto --norsrc --noextattr "$final_zip" "$output_dir/Drawstate-$version.zip"
ditto --norsrc --noextattr "$dmg" "$output_dir/Drawstate-$version.dmg"
xcrun stapler validate "$output_dir/Drawstate-$version.dmg"
hdiutil verify -quiet "$output_dir/Drawstate-$version.dmg"
(cd "$output_dir" && shasum -a 256 "Drawstate-$version.zip" > "Drawstate-$version.zip.sha256")
(cd "$output_dir" && shasum -a 256 "Drawstate-$version.dmg" > "Drawstate-$version.dmg.sha256")
echo "Notarization evidence: $evidence_dir"
echo "$output_dir/Drawstate-$version.dmg"
echo "$output_dir/Drawstate-$version.zip"
