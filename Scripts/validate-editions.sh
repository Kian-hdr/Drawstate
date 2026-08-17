#!/bin/zsh
set -euo pipefail

project_dir=${0:A:h:h}
validation_root=$(mktemp -d /private/tmp/drawstate-editions.XXXXXX)
trap 'rm -rf "$validation_root"' EXIT

swift test --package-path "$project_dir"
swift test --package-path "$project_dir" -Xswiftc -DAPP_STORE

DRAWSTATE_OUTPUT_DIR="$validation_root/direct" \
  "$project_dir/Scripts/package-app.sh" release direct
DRAWSTATE_OUTPUT_DIR="$validation_root/store" \
  "$project_dir/Scripts/package-app.sh" release app-store

direct_app="$validation_root/direct/Drawstate.app"
store_app="$validation_root/store/Drawstate-AppStore.app"

codesign --verify --deep --strict --verbose=2 "$direct_app"
codesign --verify --deep --strict --verbose=2 "$store_app"
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$direct_app/Contents/Info.plist")" == \
  "com.kiankonradtajbakhsh.drawstate" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$store_app/Contents/Info.plist")" == \
  "com.kiankonradtajbakhsh.drawstate.appstore" ]]
for key in CFBundleShortVersionString CFBundleVersion; do
  [[ "$(/usr/libexec/PlistBuddy -c "Print :$key" "$direct_app/Contents/Info.plist")" == \
    "$(/usr/libexec/PlistBuddy -c "Print :$key" "$project_dir/Resources/Info.plist")" ]]
  [[ "$(/usr/libexec/PlistBuddy -c "Print :$key" "$store_app/Contents/Info.plist")" == \
    "$(/usr/libexec/PlistBuddy -c "Print :$key" "$project_dir/Resources/Info-AppStore.plist")" ]]
done
[[ -f "$direct_app/Contents/Resources/ChargeLimitBridge.swift" ]]
[[ ! -e "$store_app/Contents/Resources/ChargeLimitBridge.swift" ]]

store_entitlements=$(codesign -d --entitlements - "$store_app" 2>&1)
grep -q 'com.apple.security.app-sandbox' <<<"$store_entitlements"
grep -q '\[Bool\] true' <<<"$store_entitlements"

store_strings=$(strings "$store_app/Contents/MacOS/Drawstate")
for forbidden in \
  ChargeLimitController \
  ChargeLimitBridge.swift \
  WFSmartChargeClientHelper \
  PowerTelemetryData \
  AppleSmartBattery \
  AdapterEfficiencyLoss \
  SystemBatterySettingsParser \
  chargeSocLimit \
  /usr/bin/pmset; do
  if grep -Fq "$forbidden" <<<"$store_strings"; then
    echo "App Store binary contains forbidden Direct-only reference: $forbidden" >&2
    exit 1
  fi
done

grep -Fq 'Learn about Drawstate Direct' <<<"$store_strings"
grep -Fq 'Open Battery Settings' <<<"$store_strings"

echo "Direct and App Store editions validated at $validation_root"
