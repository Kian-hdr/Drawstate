# Changelog

All notable changes will be documented here.

## Unreleased

- Added in-app and repository acknowledgments crediting Leon Fischer-Appelt for the original idea while retaining Kian Konrad Tajbakhsh as creator and primary developer.
- Refactored the app entry point, status-item lifecycle, dashboard, settings, icon rendering, layout, notifications, and credits into focused source files.
- Added secure local notarization through a `notarytool` Keychain profile and isolated release staging to prevent File Provider metadata from invalidating signatures.
- Prepared Drawstate for public open-source development.
- Added universal Apple Silicon and Intel release builds.
- Added Developer ID notarization automation and a privacy manifest.
- Replaced the custom persistent LaunchAgent with the standard macOS login-item service.
- Made undocumented charge-limit control explicitly experimental for new users.
