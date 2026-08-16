# Drawstate AI Maintenance Guide

This is the canonical, model-neutral instruction file for AI coding tools working on Drawstate. Codex, Claude Code, Kimi, and other assistants should read this file completely before inspecting or changing the project. `CLAUDE.md` is only a discovery pointer to this guide.

User instructions and higher-priority system instructions override this document. Preserve unrelated user changes, inspect the current implementation before editing, and never claim a validation step passed unless it was actually run.

## Product contract

Drawstate is a native, local-only macOS menu bar utility that reports live power and battery telemetry. It must:

- Run without administrator privileges, a privileged helper, `powermetrics`, cloud services, or analytics.
- Remain a menu-bar-only app with no Dock icon (`LSUIElement` is true).
- Show compact, user-configurable menu information for battery percentage, signed wattage, and runtime.
- Open a live details popover when its menu-bar control is clicked.
- Offer opt-in startup through the standard macOS login-item service.
- Degrade missing hardware telemetry to `—` or `Calculating…`, never a fabricated zero.
- Preserve the creator credit, Kian Konrad Tajbakhsh, and the MIT open-source license.

The readings are estimates from macOS and battery telemetry, not calibrated wall-meter measurements.

## Project and installation paths

- Source: `/Users/kian/Documents/Codex/Drawstate`
- Installed application: `/Applications/Drawstate.app`
- Login item: `SMAppService.mainApp`, managed by macOS under Login Items
- Bundle identifier: `com.kiankonradtajbakhsh.drawstate`

Do not reintroduce former product names or legacy identifiers in source, documentation, build products, processes, or login items.

## Architecture map

| File | Responsibility |
| --- | --- |
| `Sources/Drawstate/DrawstateApp.swift` | App lifecycle, menu-bar carrier, popover, detailed UI, preferences UI, menu icon rendering, and welcome-window presentation. |
| `Sources/Drawstate/DrawstateWelcomeView.swift` | First-run welcome experience and creator/open-source information. |
| `Sources/Drawstate/LaunchAtLoginManager.swift` | Standard login-item registration, approval handling, and legacy LaunchAgent migration. |
| `Sources/Drawstate/PowerMonitor.swift` | One-second telemetry sampling, smoothing, runtime-state handling, wake/source-change resets, and published UI state. |
| `Sources/DrawstateCore/PowerSample.swift` | Typed raw and derived power sample model. Keep unavailable measurements distinct from numeric zero. |
| `Sources/DrawstateCore/Telemetry.swift` | IOPowerSources and AppleSmartBattery IOKit parsing. Hardware keys vary, so preserve graceful fallback behavior. |
| `Sources/DrawstateCore/PowerEstimator.swift` | Derived power flow, runtime estimation, formatting, and smoothing logic. |
| `Tests/DrawstateCoreTests/DrawstateCoreTests.swift` | Parsing, signs, calculations, formatting, missing-data, and flow-direction tests. |
| `Scripts/package-app.sh` | Release build and `.app` bundle packaging. |

The package has a reusable `DrawstateCore` library, a `Drawstate` executable, and `DrawstateCoreTests`. Keep telemetry and calculation logic in the core target when practical so it remains unit-testable.

## Critical menu-bar implementation

The menu-bar carrier is a native AppKit `NSStatusItem` owned by `DrawstateAppDelegate`:

- It uses variable length so macOS automatically lays out the enabled icon and text.
- Its stable `autosaveName` preserves the user's preferred menu-bar position.
- Its removal behavior enables native Command-drag repositioning and removal.
- The status-item button toggles an `NSPopover` containing `DrawstatePanel`.
- `DrawstatePanel` switches in place between the live dashboard and embedded settings. Its Settings button must not open a separate window.
- `DrawstatePopoverLayout` constrains both overview and settings to one stable width and caps the settings height using the visible frame of the screen containing the status item. Update it before every popover presentation so secondary displays and changed resolutions remain safe.
- After opening, the implementation clears the first responder so the Settings control does not retain an unwanted blue focus ring.

Do not replace the native item with a manually positioned `NSPanel`. That approach does not participate in menu-bar layout and cannot support native Command-drag repositioning. Also avoid a `TimelineView` inside a SwiftUI `MenuBarExtra` label; an earlier version caused an unbounded update loop. Sampling and status-item updates belong to `PowerMonitor` and `DrawstateAppDelegate`.

Any carrier change must be visually verified on this Mac. A running process is not proof that the menu item is visible, correctly positioned, or clickable.

## Power-flow semantics

Keep raw telemetry, derived flows, availability, timestamps, and source labels separate.

- Positive menu wattage means power is entering or charging the battery.
- Negative menu wattage means the battery is supplying power to the Mac.
- Adapter input, adapter contribution to system load, total system load, and battery flow are different measurements. Do not label one as another.
- Battery current is signed. Confirm the sign convention with existing fixtures before changing calculations.
- Simultaneous adapter and battery supply is possible with a weak charger or high load.
- Charging may pause because of optimized charging or thermal/system decisions while an adapter is connected.
- Reset or rapidly adapt runtime estimates after a plug/unplug event, wake from sleep, telemetry gap, or major battery-flow change.
- Prefer the system runtime estimate when valid. Use a clearly marked approximation only after sufficient stable samples.

Never convert missing data into `0 W`, `0 V`, `0 A`, or `0 min`.

## Preferences and defaults

Preferences use `UserDefaults`. Preserve existing user choices during builds, upgrades, and fixes. Do not rename a key without a migration.

Current feature keys include:

- `showMenuIcon`
- `showMenuPercentage`
- `showMenuWattage`
- `showMenuRuntime`
- `showPowerDirectionSign`
- `compactMenuText`
- `hideTemporaryMenuStates`
- `percentageInsideBatteryIcon`
- `smoothReadings`
- `showFlowDiagram`
- `showMacDrawCard`
- `showWallDrawCard`
- `showPowerPlugCard`
- `showBatteryCard`
- `showBatteryFlowCard`
- `showRuntimeCard`
- `showElectricalDetails`
- `showBatterySettingsCard`
- `experimentalChargeLimitControl`
- `hasCompletedWelcome`
- `launchAtLoginConfigured`

Every user-visible feature should remain independently switchable when that is meaningful. Ensure a combination of disabled menu text options still leaves a clickable, recognizable menu control.

The integrated percentage icon uses an Apple-style battery outline with a live interior fill and precisely centered percentage digits. The fill tracks the actual battery level and turns red at 20% or below. Digits are composited separately over filled and empty regions to remain legible. It is intentionally a non-template image cached separately for light and dark appearances. The Original appearance option must remain available.

## Startup behavior

`LaunchAtLoginManager` uses the standard `SMAppService.mainApp` login-item API. New public installations do not enable startup silently. Existing installations migrate the former per-user LaunchAgent once, remove its plist, and preserve the user's enabled startup choice through `SMAppService`.

Do not restore `KeepAlive` relaunch behavior for public builds. Quitting must remain meaningful. When changing startup code, validate registration, required-approval handling, disabling, and the one-time legacy migration.

## Build, test, and package

Run commands from `/Users/kian/Documents/Codex/Drawstate`.

```bash
swift test
./Scripts/package-app.sh release
codesign --verify --deep --strict --verbose=2 build/Drawstate.app
```

The packaging script creates `build/Drawstate.app`. Install it as `/Applications/Drawstate.app`, not in `/Users/kian/Applications` and not beside the source tree.

After successfully installing and verifying the app, move the packaged `build/Drawstate.app` to Trash so Finder and Spotlight do not show duplicate copies. Do not remove an existing application copy until the intended source and target paths have been resolved explicitly.

## Required validation

Choose checks proportionate to the change, but menu, lifecycle, startup, and telemetry changes require the full relevant set.

1. Run all XCTest tests and report the exact pass/fail result.
2. Build the Release application and verify its code signature.
3. Confirm the installed bundle is exactly `/Applications/Drawstate.app`.
4. Confirm `LSUIElement` remains true and no Dock icon appears.
5. Launch through Finder or `open`, not by invoking the executable directly.
6. Visually verify that the control is present in the menu bar.
7. Click it and verify the popover is anchored to the menu control, opens once, and contains live data.
8. Confirm the Settings button is not permanently focused with a blue ring.
9. Confirm the login-item toggle registers and unregisters through macOS, and that Quit does not relaunch the app immediately.
10. Confirm there is only one installed/indexed Drawstate application and no legacy process or login item.
11. Search for known legacy product names and identifiers. Explain any occurrence that must intentionally remain.

For charger-connected behavior, unplugged behavior, sleep/wake, or workload response, state whether the physical state was actually tested. Do not infer a live hardware result solely from unit fixtures.

Useful read-only checks include:

```bash
pgrep -fl Drawstate
plutil -p /Applications/Drawstate.app/Contents/Info.plist
system_profiler SPLoginItemDataType
mdfind 'kMDItemFSName == "Drawstate.app"c'
```

## Change discipline

- Prefer the smallest coherent change that fixes the root cause.
- Preserve unrelated work and current preferences.
- Use SwiftUI for views and AppKit only where the menu-bar/window behavior requires it.
- Keep UI mutations on the main actor.
- Avoid timers or view invalidation loops in menu labels. Sampling is owned by `PowerMonitor`.
- Add or update tests for parsing, signed values, smoothing, runtime formatting, missing telemetry, and flow direction when those behaviors change.
- Do not add new privileges, daemons, kernel/system extensions, network calls, analytics, or dependencies without explicit user approval.
- Charge-limit writes are an explicitly experimental, opt-in exception to the normal read-only design. New users default to read-only charge-limit display. Never load ActionKit inside Drawstate or an ad-hoc executable: its static initializer aborts there. `ChargeLimitBridge.swift` runs out-of-process through Apple’s signed `/usr/bin/swift`, uses Apple’s undocumented on-device `WFSmartChargeClientHelper`, verifies every write, and returns a bounded result. A bridge crash or rejection must become a recoverable UI error and must never close Drawstate. Do not add administrator credentials, a privileged daemon, or raw SMC writes.
- Keep README behavior, settings labels, tests, bundle metadata, startup configuration, and source names synchronized.
- Never report the repair as complete based only on a successful build or a live PID. Validate the user-visible behavior.

## Definition of done

A modification is complete only when the requested behavior is implemented, applicable tests/builds pass, the installed app is verified when installation is in scope, and any untested physical or visual behavior is disclosed. The final handoff should state:

- What changed.
- Which tests and verification steps passed, failed, or were not run.
- Whether the installed app was replaced and launched.
- Whether login-item behavior was checked.
- Any remaining hardware-dependent or visual limitation.
