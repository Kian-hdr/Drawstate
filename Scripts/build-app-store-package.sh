#!/bin/zsh
set -euo pipefail

project_dir=${0:A:h:h}
version=${1:?Usage: Scripts/build-app-store-package.sh VERSION BUILD_NUMBER}
build_number=${2:?Usage: Scripts/build-app-store-package.sh VERSION BUILD_NUMBER}
release_root=$(mktemp -d /private/tmp/drawstate-app-store.XXXXXX)
trap 'rm -rf "$release_root"' EXIT

: "${DRAWSTATE_APP_STORE_SIGNING_IDENTITY:?Set DRAWSTATE_APP_STORE_SIGNING_IDENTITY to an Apple Distribution certificate}"
: "${DRAWSTATE_APP_STORE_INSTALLER_IDENTITY:?Set DRAWSTATE_APP_STORE_INSTALLER_IDENTITY to a Mac Installer Distribution certificate}"
: "${DRAWSTATE_APP_STORE_PROVISIONING_PROFILE:?Set DRAWSTATE_APP_STORE_PROVISIONING_PROFILE to the App Store profile path}"

DRAWSTATE_VERSION="$version" \
DRAWSTATE_BUILD_NUMBER="$build_number" \
DRAWSTATE_OUTPUT_DIR="$release_root" \
  "$project_dir/Scripts/package-app.sh" release app-store

app="$release_root/Drawstate-AppStore.app"
package="$project_dir/build/Drawstate-AppStore-$version-$build_number.pkg"
rm -f "$package"
productbuild \
  --sign "$DRAWSTATE_APP_STORE_INSTALLER_IDENTITY" \
  --component "$app" /Applications \
  "$package"
pkgutil --check-signature "$package"
echo "$package"
