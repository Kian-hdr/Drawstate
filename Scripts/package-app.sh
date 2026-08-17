#!/bin/zsh
set -euo pipefail

project_dir=${0:A:h:h}
configuration=${1:-release}
edition=${2:-direct}
output_dir=${DRAWSTATE_OUTPUT_DIR:-"$project_dir/build"}

case "$edition" in
  direct)
    app_name="Drawstate.app"
    info_plist="$project_dir/Resources/Info.plist"
    signing_identity=${DRAWSTATE_SIGNING_IDENTITY:--}
    entitlements=""
    ;;
  app-store)
    app_name="Drawstate-AppStore.app"
    info_plist="$project_dir/Resources/Info-AppStore.plist"
    signing_identity=${DRAWSTATE_APP_STORE_SIGNING_IDENTITY:--}
    entitlements="$project_dir/Resources/Drawstate-AppStore.entitlements"
    ;;
  *)
    echo "Unknown edition '$edition'. Use 'direct' or 'app-store'." >&2
    exit 64
    ;;
esac

final_app_dir="$output_dir/$app_name"

# Assemble and sign outside Documents. File Provider can immediately attach
# Finder metadata to bundles in Documents, which Developer ID signing rejects.
staging_root=$(mktemp -d /private/tmp/drawstate-package.XXXXXX)
app_dir="$staging_root/$app_name"
trap 'rm -rf "$staging_root"' EXIT

build_arguments=(--package-path "$project_dir" -c "$configuration")
if [[ "$edition" == "app-store" ]]; then
  build_arguments+=(-Xswiftc -DAPP_STORE)
fi
if [[ "$configuration" == "release" ]]; then
  build_arguments+=(--arch arm64 --arch x86_64)
fi

mkdir -p "$project_dir/build" "$output_dir"
touch "$project_dir/build/.metadata_never_index"

swift build "${build_arguments[@]}"
binary_dir=$(swift build "${build_arguments[@]}" --show-bin-path)

mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$binary_dir/Drawstate" "$app_dir/Contents/MacOS/Drawstate"
if [[ "$edition" == "direct" ]]; then
  cp "$project_dir/Resources/ChargeLimitBridge.swift" "$app_dir/Contents/Resources/ChargeLimitBridge.swift"
fi
cp "$info_plist" "$app_dir/Contents/Info.plist"
if [[ -n "${DRAWSTATE_VERSION:-}" ]]; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $DRAWSTATE_VERSION" "$app_dir/Contents/Info.plist"
fi
if [[ -n "${DRAWSTATE_BUILD_NUMBER:-}" ]]; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $DRAWSTATE_BUILD_NUMBER" "$app_dir/Contents/Info.plist"
fi
if [[ "$edition" == "app-store" && -n "${DRAWSTATE_APP_STORE_PROVISIONING_PROFILE:-}" ]]; then
  cp "$DRAWSTATE_APP_STORE_PROVISIONING_PROFILE" "$app_dir/Contents/embedded.provisionprofile"
fi

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
  if [[ -n "$entitlements" ]]; then
    codesign --force --deep --entitlements "$entitlements" --sign - "$app_dir"
  else
    codesign --force --deep --sign - "$app_dir"
  fi
else
  signing_arguments=(--force --deep --options runtime --timestamp --sign "$signing_identity")
  if [[ -n "$entitlements" ]]; then
    signing_arguments+=(--entitlements "$entitlements")
  fi
  codesign "${signing_arguments[@]}" "$app_dir"
fi

codesign --verify --deep --strict --verbose=2 "$app_dir"
file "$app_dir/Contents/MacOS/Drawstate"

rm -rf "$final_app_dir"
ditto --norsrc --noextattr "$app_dir" "$final_app_dir"
# File Provider can attach Finder metadata immediately after the destination copy even when
# `ditto --noextattr` is used. Clear it once more before the final strict signature check.
xattr -cr "$final_app_dir"
codesign --verify --deep --strict --verbose=2 "$final_app_dir"

echo "$final_app_dir"
