# Architecture

Drawstate is a native SwiftUI and AppKit menu-bar app with no server component. One source tree produces Drawstate Direct and a separately sandboxed Mac App Store edition.

- `DrawstateMain.swift`: SwiftUI entry point and startup bootstrap
- `DrawstateAppDelegate.swift`: native status item, popover coordination, and menu rendering
- `DrawstatePanel.swift`: live telemetry dashboard and power-flow cards
- `DrawstateSettings.swift`: integrated preferences, About, and acknowledgments
- `DrawstateMenuIconFactory.swift`: percentage-inside battery icon rendering
- `DrawstatePopoverLayout.swift`: screen-aware popover sizing
- `DrawstateCredits.swift`: canonical in-app creator and acknowledgment wording
- `PowerMonitor.swift`: one-second sampling and published live state
- `Telemetry.swift`: public IOPowerSources parsing in both editions and Direct-only AppleSmartBattery parsing
- `PowerEstimator.swift`: power-flow derivation, smoothing, formatting, and runtime estimation
- `SystemBatterySettings.swift`: energy-mode and charge-limit parsing
- `ChargeLimitController.swift`: Direct-only isolated experimental control bridge
- `LaunchAtLoginManager.swift`: standard `SMAppService` login registration and legacy migration

The `DrawstateCore` target contains testable telemetry and calculation logic. Missing readings remain optional throughout the model.

## Edition boundary

`APP_STORE` is a Swift compile condition, not a runtime preference. The Store executable cannot enter or contain Direct-only charge-control and private-telemetry paths. `Scripts/package-app.sh release app-store` adds the condition, uses Store metadata and sandbox entitlements, and omits the Swift bridge resource. `Scripts/validate-editions.sh` checks both sides of this boundary.

The Direct build remains the default packaging path and retains its existing bundle identifier and features. See [EDITIONS.md](EDITIONS.md) for the feature and telemetry matrix.
