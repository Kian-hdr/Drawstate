#!/bin/zsh
set -euo pipefail

project_dir=${0:A:h:h}
configuration=${1:-release}
app_dir="$project_dir/build/Drawstate.app"
signing_identity=${DRAWSTATE_SIGNING_IDENTITY:--}

build_arguments=(--package-path "$project_dir" -c "$configuration")
if [[ "$configuration" == "release" ]]; then
  build_arguments+=(--arch arm64 --arch x86_64)
fi

mkdir -p "$project_dir/build"
touch "$project_dir/build/.metadata_never_index"

swift build "${build_arguments[@]}"
binary_dir=$(swift build "${build_arguments[@]}" --show-bin-path)

rm -rf "$app_dir"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$binary_dir/Drawstate" "$app_dir/Contents/MacOS/Drawstate"
cp "$project_dir/Resources/ChargeLimitBridge.swift" "$app_dir/Contents/Resources/ChargeLimitBridge.swift"
cp "$project_dir/Resources/Info.plist" "$app_dir/Contents/Info.plist"

# Xcode 26's Icon Composer format supplies native Default, Dark, and Mono
# appearances. Older Xcode versions cannot compile a .icon package, so public
# source builds retain the transparent-corner ICNS artwork as a safe fallback.
icon_build_dir=$(mktemp -d "$project_dir/build/icon-assets.XXXXXX")
trap 'rm -rf "$icon_build_dir"' EXIT
if xcrun actool "$project_dir/Resources/Drawstate.icon" \
  --compile "$icon_build_dir" \
  --platform macosx \
  --minimum-deployment-target 14.0 \
  --app-icon Drawstate \
  --output-partial-info-plist "$icon_build_dir/IconInfo.plist" \
  --warnings --notices >/dev/null 2>&1; then
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

echo "$app_dir"
