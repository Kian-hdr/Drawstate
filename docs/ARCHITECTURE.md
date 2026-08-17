# Architecture

Drawstate is a native SwiftUI and AppKit menu-bar app with no server component.

- `DrawstateMain.swift`: SwiftUI entry point and startup bootstrap
- `DrawstateAppDelegate.swift`: native status item, popover coordination, and menu rendering
- `DrawstatePanel.swift`: live telemetry dashboard and power-flow cards
- `DrawstateSettings.swift`: integrated preferences, About, and acknowledgments
- `DrawstateMenuIconFactory.swift`: percentage-inside battery icon rendering
- `DrawstatePopoverLayout.swift`: screen-aware popover sizing
- `DrawstateCredits.swift`: canonical in-app creator and acknowledgment wording
- `PowerMonitor.swift`: one-second sampling and published live state
- `Telemetry.swift`: IOPowerSources and AppleSmartBattery parsing
- `PowerEstimator.swift`: power-flow derivation, smoothing, formatting, and runtime estimation
- `SystemBatterySettings.swift`: energy-mode and charge-limit parsing
- `ChargeLimitController.swift`: isolated experimental control bridge
- `LaunchAtLoginManager.swift`: standard `SMAppService` login registration and legacy migration

The `DrawstateCore` target contains testable telemetry and calculation logic. Missing readings remain optional throughout the model.
