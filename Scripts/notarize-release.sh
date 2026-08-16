#!/bin/zsh
set -euo pipefail

project_dir=${0:A:h:h}
version=${1:?Usage: Scripts/notarize-release.sh VERSION}
app_dir="$project_dir/build/Drawstate.app"
archive="$project_dir/build/Drawstate-$version.zip"

: "${DRAWSTATE_SIGNING_IDENTITY:?Set DRAWSTATE_SIGNING_IDENTITY}"
: "${APPLE_ID:?Set APPLE_ID}"
: "${APPLE_TEAM_ID:?Set APPLE_TEAM_ID}"
: "${APPLE_APP_SPECIFIC_PASSWORD:?Set APPLE_APP_SPECIFIC_PASSWORD}"

"$project_dir/Scripts/package-app.sh" release
rm -f "$archive"
ditto -c -k --keepParent "$app_dir" "$archive"

xcrun notarytool submit "$archive" \
  --apple-id "$APPLE_ID" \
  --team-id "$APPLE_TEAM_ID" \
  --password "$APPLE_APP_SPECIFIC_PASSWORD" \
  --wait

xcrun stapler staple "$app_dir"
xcrun stapler validate "$app_dir"
spctl --assess --type execute --verbose=2 "$app_dir"

rm -f "$archive"
ditto -c -k --keepParent "$app_dir" "$archive"
shasum -a 256 "$archive" > "$archive.sha256"
echo "$archive"
