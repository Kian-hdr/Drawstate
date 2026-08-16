# Architecture

Drawstate is a native SwiftUI and AppKit menu-bar app with no server component.

- `DrawstateApp.swift`: lifecycle, native status item, popover, settings, and menu rendering
- `PowerMonitor.swift`: one-second sampling and published live state
- `Telemetry.swift`: IOPowerSources and AppleSmartBattery parsing
- `PowerEstimator.swift`: power-flow derivation, smoothing, formatting, and runtime estimation
- `SystemBatterySettings.swift`: energy-mode and charge-limit parsing
- `ChargeLimitController.swift`: isolated experimental control bridge
- `LaunchAtLoginManager.swift`: standard `SMAppService` login registration and legacy migration

The `DrawstateCore` target contains testable telemetry and calculation logic. Missing readings remain optional throughout the model.
