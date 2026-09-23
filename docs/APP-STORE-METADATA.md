# Mac App Store Metadata

This file is the canonical listing source for Drawstate 1.0.2, build 3. Review live App Store Connect fields against it before submission.

## Identity

- Name: Drawstate
- Subtitle: Live Mac power telemetry
- Primary language: English (U.S.)
- Bundle ID: `com.kiankonradtajbakhsh.drawstate.appstore`
- SKU: `drawstate-macos-001`
- Version: 1.0.2
- Build: 3
- Primary category: Utilities
- Secondary category: None
- Copyright: 2026 Kian Konrad Tajbakhsh
- Content rights: Drawstate does not contain, show, or access third-party content.
- License agreement: Apple's standard EULA
- Release method: Manual release after approval

## URLs

- Marketing URL: https://github.com/Kian-hdr/Drawstate
- Support URL: https://github.com/Kian-hdr/Drawstate/blob/main/SUPPORT.md
- Privacy policy URL: https://github.com/Kian-hdr/Drawstate/blob/main/PRIVACY.md

## Promotional text

See live Mac and compatible power-bank telemetry in your menu bar, with configurable wattage, charge status, battery percentage, and runtime estimates.

## Description

Drawstate puts clear, live battery and power telemetry in your Mac menu bar.

See battery percentage, signed power flow, and estimated time until full or empty without opening System Settings. Click the menu-bar item for a detailed local dashboard covering battery flow, voltage, current, charger capability, energy mode, and available runtime information.

Choose exactly what appears in the menu bar, switch between battery icon styles, smooth changing values, and optionally start Drawstate when you log in. Missing hardware measurements appear as unavailable rather than being presented as zero.

Compatible USB HID/UPS power banks appear automatically in a compact conditional card with their reported remaining charge, state, electrical output, and runtime. Unsupported devices leave the interface unchanged. Calculated values are clearly labeled as estimates.

The Mac App Store edition is sandboxed and uses IOPowerSources plus read-only IOKit telemetry for live wattage and power flow. Compatible external sources use documented IOPowerSources and USB descriptor APIs under the USB sandbox entitlement. It does not include experimental charge-limit controls. Its compact Battery Settings card shows the current energy mode and opens macOS Battery Settings. The app links to its Privacy Policy from Settings.

Drawstate works locally with no account, analytics, advertising, cloud service, or tracking.

Created and developed by Kian Konrad Tajbakhsh. Inspired by an original idea from Leon Fischer-Appelt.

## Keywords

`battery,power,wattage,charging,energy,menu bar,runtime,telemetry,charger,power bank,UPS,USB`

## What's New

Initial Mac App Store release with live menu-bar battery and power telemetry, conditional support for compatible USB HID/UPS power banks, configurable status information, runtime estimates, an integrated dashboard, and sandboxed Battery Settings access.

## App privacy

- Tracking: No
- Data collected: None
- Data linked to the user: None
- Data used for tracking: None
- Privacy manifest: UserDefaults reason `CA92.1`; no collected-data or tracking declarations

## Age rating answers

Drawstate contains no objectionable content, user-generated content, messaging, advertising, web browsing, gambling, loot boxes, simulated gambling, contests, medical content, alcohol, tobacco, drugs, violence, sexual content, profanity, horror, or unrestricted web access. Complete each live questionnaire answer truthfully as None or No where its wording matches these capabilities. Do not predetermine the final rating before App Store Connect calculates it.

## Distribution

- Price: Free
- Availability: All territories where Apple permits distribution, subject to completed legal and trader-status requirements
- Pre-orders: No
- Mac App Store edition: sandboxed build using IOPowerSources and disclosed read-only IOKit registry telemetry
- No alternate-edition installation link in the Store app
- Platform and availability: macOS only; do not add iOS, iPadOS, tvOS, watchOS, or visionOS versions

## Screenshots

Use only the sandboxed `APP_STORE` UI and an accepted 16:10 Mac screenshot size. Do not show Drawstate Direct controls or private user information.

Captured from the Store QA app's separate macOS Settings window on 2026-09-23, then removed from App Store Connect after Kian pointed out that this window looks different from Settings embedded inside Drawstate's menu-bar popover:

- `AppStore/Screenshots/02-customize.png`: real Store Settings window, menu-bar and appearance controls, on a neutral 1440 × 900 canvas.
- `AppStore/Screenshots/03-privacy.png`: real Store Settings window, details and privacy controls, on a neutral 1440 × 900 canvas.

Both use local captures of the 1.0.2 (3) Store package payload, re-signed only for sandboxed runtime QA. App Store Connect currently has no screenshots. The current Direct and Store app bundles both report version 1.0.2 (3); the visual discrepancy came from capturing `DrawstateSettings()` in its standalone scene instead of `DrawstateSettings(isEmbedded: true)` inside the panel. Capture and upload the live Store-edition menu-bar panel and its embedded Settings view. Keep hardware-dependent values truthful and do not substitute Direct-edition controls, especially its charge-limit display and slider.
