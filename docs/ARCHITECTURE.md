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
- `Telemetry.swift`: IOPowerSources parsing plus read-only AppleSmartBattery power-controller telemetry in both editions
- `PowerEstimator.swift`: power-flow derivation, smoothing, formatting, and runtime estimation
- `PowerBankTelemetry.swift`: typed external-battery model, UPS parsing, visibility rules, source selection, and estimates
- `PowerBankProviders.swift`: public IOPowerSources/HID-UPS reader, USB identity enrichment, and vendor-provider protocols
- `SystemBatterySettings.swift`: energy-mode and charge-limit parsing
- `ChargeLimitController.swift`: Direct-only isolated experimental control bridge
- `LaunchAtLoginManager.swift`: standard `SMAppService` login registration and legacy migration

The `DrawstateCore` target contains testable telemetry and calculation logic. Missing readings remain optional throughout the model.

## External power sources

Power-bank data never enters the Mac's `PowerSample`. `PowerBankSample` has its own identity, state, measurements, source, and timestamp so an external battery cannot be confused with the Mac battery. `IOPowerSourcesPowerBankProvider` accepts only the documented external `UPS` type. `IOKitUSBIdentityProvider` reads public USB descriptor properties only after a compatible power source exists and never infers a battery from an ordinary USB-C device.

`PowerBankTelemetryProvider` and `PowerBankIdentityProvider` isolate future documented vendor integrations. Providers are read-only and must return no sample unless they have usable telemetry. `PowerMonitor` samples them on its existing one-second cycle, resets smoothing and percentage-slope estimates on identity changes or wake, removes disconnected/stale sources immediately, and selects a deterministic active source when multiple external batteries are present.

## Edition boundary

`APP_STORE` is a Swift compile condition, not a runtime preference. The Store executable cannot enter or contain Direct-only charge-control paths. It retains read-only power-controller telemetry because live wattage is Drawstate's core function. Its power-bank path uses documented IOPowerSources and USB APIs and declares the App Sandbox USB hardware entitlement. `Scripts/package-app.sh release app-store` adds the condition, uses Store metadata and sandbox entitlements, and omits the Swift bridge resource. `Scripts/validate-editions.sh` checks both sides of this boundary.

The Direct build remains the default packaging path and retains its existing bundle identifier and features. See [EDITIONS.md](EDITIONS.md) for the feature and telemetry matrix.
