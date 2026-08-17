#!/bin/zsh
set -euo pipefail

project_dir=${0:A:h:h}
configuration=${1:-release}
output_dir=${DRAWSTATE_OUTPUT_DIR:-"$project_dir/build"}
final_app_dir="$output_dir/Drawstate.app"
signing_identity=${DRAWSTATE_SIGNING_IDENTITY:--}

# Assemble and sign outside Documents. File Provider can immediately attach
# Finder metadata to bundles in Documents, which Developer ID signing rejects.
staging_root=$(mktemp -d /private/tmp/drawstate-package.XXXXXX)
app_dir="$staging_root/Drawstate.app"
trap 'rm -rf "$staging_root"' EXIT

build_arguments=(--package-path "$project_dir" -c "$configuration")
if [[ "$configuration" == "release" ]]; then
  build_arguments+=(--arch arm64 --arch x86_64)
fi

mkdir -p "$project_dir/build" "$output_dir"
touch "$project_dir/build/.metadata_never_index"

swift build "${build_arguments[@]}"
binary_dir=$(swift build "${build_arguments[@]}" --show-bin-path)

mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$binary_dir/Drawstate" "$app_dir/Contents/MacOS/Drawstate"
cp "$project_dir/Resources/ChargeLimitBridge.swift" "$app_dir/Contents/Resources/ChargeLimitBridge.swift"
cp "$project_dir/Resources/Info.plist" "$app_dir/Contents/Info.plist"

# Xcode 26's Icon Composer format supplies native Default, Dark, and Mono
# appearances. Older Xcode versions cannot compile a .icon package, so public
# source builds retain the transparent-corner ICNS artwork as a safe fallback.
icon_build_dir=$(mktemp -d "$project_dir/build/icon-assets.XXXXXX")
trap 'rm -rf "$icon_build_dir" "$staging_root"' EXIT
if xcrun actool "$project_dir/Resources/Drawstate.icon" \
  --compile "$icon_build_dir" \
  --platform macosx \
  --minimum-deployment-target 14.0 \
  --app-icon Drawstate \
  --output-partial-info-plist "$icon_build_dir/IconInfo.plist" \
  --warnings --notices >/dev/null 2>&1 \
  && [[ -f "$icon_build_dir/Drawstate.icns" ]] \
  && [[ -f "$icon_build_dir/Assets.car" ]]; then
  cp "$icon_build_dir/Drawstate.icns" "$app_dir/Contents/Resources/Drawstate.icns"
  cp "$icon_build_dir/Assets.car" "$app_dir/Contents/Resources/Assets.car"
  echo "Compiled adaptive Icon Composer artwork."
else
  cp "$project_dir/Resources/AppIcon.icns" "$app_dir/Contents/Resources/Drawstate.icns"
  echo "Icon Composer compilation unavailable; using the compatible ICNS fallback."
fi
cp "$project_dir/Resources/PrivacyInfo.xcprivacy" "$app_dir/Contents/Resources/PrivacyInfo.xcprivacy"
cp "$project_dir/LICENSE" "$app_dir/Contents/Resources/LICENSE.txt"
xattr -cr "$app_dir"
if [[ "$signing_identity" == "-" ]]; then
  codesign --force --deep --sign - "$app_dir"
else
  codesign --force --deep --options runtime --timestamp --sign "$signing_identity" "$app_dir"
fi

codesign --verify --deep --strict --verbose=2 "$app_dir"
file "$app_dir/Contents/MacOS/Drawstate"

rm -rf "$final_app_dir"
ditto --norsrc --noextattr "$app_dir" "$final_app_dir"
codesign --verify --deep --strict --verbose=2 "$final_app_dir"

echo "$final_app_dir"
