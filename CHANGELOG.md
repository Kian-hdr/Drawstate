# Changelog

All notable changes will be documented here.

## 1.0.2 - 2026-09-23

- Added an in-app Privacy Policy link to the Mac App Store edition.
- Kept the Store edition focused on read-only battery information and removed its alternate-edition installation page.
- Prepared separate, controlled Mac App Store and direct-download release workflows.

## 1.0.1 - 2026-08-17

- Added a separately sandboxed Mac App Store build using the `APP_STORE` compile condition.
- Excluded undocumented charge-limit writing, its Swift bridge, and `pmset` execution from the Store executable; retained read-only AppleSmartBattery IORegistry telemetry for power-flow display.
- Added the Store Battery Settings shortcut, Drawstate Direct information card, edition validation, App Review notes, and Store signing and upload documentation.
- Kept Drawstate Direct as the unchanged GitHub Releases and Homebrew edition with its experimental charge-limit controls.
- Removed the duplicate primary-developer row from About so the creator credit appears once.
- Added in-app and repository acknowledgments crediting Leon Fischer-Appelt for the original idea while retaining Kian Konrad Tajbakhsh as creator and primary developer.
- Refactored the app entry point, status-item lifecycle, dashboard, settings, icon rendering, layout, notifications, and credits into focused source files.
- Added secure local notarization through a `notarytool` Keychain profile and isolated release staging to prevent File Provider metadata from invalidating signatures.
- Prepared Drawstate for public open-source development.
- Added universal Apple Silicon and Intel release builds.
- Added Developer ID notarization automation and a privacy manifest.
- Replaced the custom persistent LaunchAgent with the standard macOS login-item service.
- Made undocumented charge-limit control explicitly experimental for new users.
