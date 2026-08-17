#!/bin/zsh
set -euo pipefail

project_dir=${0:A:h:h}
version=${1:?Usage: Scripts/notarize-release.sh VERSION}
archive="$project_dir/build/Drawstate-$version.zip"
release_dir=$(mktemp -d /private/tmp/drawstate-release.XXXXXX)
app_dir="$release_dir/Drawstate.app"
trap 'rm -rf "$release_dir"' EXIT

: "${DRAWSTATE_SIGNING_IDENTITY:?Set DRAWSTATE_SIGNING_IDENTITY}"

notary_arguments=()
if [[ -n "${DRAWSTATE_NOTARY_PROFILE:-}" ]]; then
  notary_arguments+=(--keychain-profile "$DRAWSTATE_NOTARY_PROFILE")
else
  : "${APPLE_ID:?Set APPLE_ID or DRAWSTATE_NOTARY_PROFILE}"
  : "${APPLE_TEAM_ID:?Set APPLE_TEAM_ID or DRAWSTATE_NOTARY_PROFILE}"
  : "${APPLE_APP_SPECIFIC_PASSWORD:?Set APPLE_APP_SPECIFIC_PASSWORD or DRAWSTATE_NOTARY_PROFILE}"
  notary_arguments+=(
    --apple-id "$APPLE_ID"
    --team-id "$APPLE_TEAM_ID"
    --password "$APPLE_APP_SPECIFIC_PASSWORD"
  )
fi

DRAWSTATE_VERSION="$version" DRAWSTATE_OUTPUT_DIR="$release_dir" \
  "$project_dir/Scripts/package-app.sh" release direct
rm -f "$archive"
ditto -c -k --keepParent --norsrc "$app_dir" "$archive"

xcrun notarytool submit "$archive" "${notary_arguments[@]}" --wait

xcrun stapler staple "$app_dir"
xcrun stapler validate "$app_dir"
spctl --assess --type execute --verbose=2 "$app_dir"

rm -f "$archive"
ditto -c -k --keepParent --norsrc "$app_dir" "$archive"
shasum -a 256 "$archive" > "$archive.sha256"
echo "$archive"
