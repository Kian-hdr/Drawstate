# Mac App Store Metadata

This file is the canonical listing source for Drawstate 1.0.1, build 2. Review live App Store Connect fields against it before submission.

## Identity

- Name: Drawstate
- Subtitle: Live Mac power telemetry
- Primary language: English (U.S.)
- Bundle ID: `com.kiankonradtajbakhsh.drawstate.appstore`
- SKU: `drawstate-macos-001`
- Version: 1.0.1
- Build: 2
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

The Mac App Store edition is sandboxed and uses IOPowerSources plus read-only IOKit telemetry for live wattage and power flow. Compatible external sources use documented IOPowerSources and USB descriptor APIs under the USB sandbox entitlement. It does not include Drawstate Direct's experimental charge-limit controls. Its compact Battery Settings card links to an in-app explanation of the GitHub Releases and Homebrew options. Clicking the displayed Homebrew command copies it to the clipboard; the page's only external action opens the official installation documentation. It does not download, install, execute, or replace software.

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
- Drawstate Direct link: informational link to https://github.com/Kian-hdr/Drawstate#install
- Platform and availability: macOS only; do not add iOS, iPadOS, tvOS, watchOS, or visionOS versions

## Screenshots

Use only the sandboxed `APP_STORE` build and an accepted 16:10 Mac screenshot size. Do not show Drawstate Direct controls or private user information.

1. Charging overview
2. Battery runtime overview
3. Embedded appearance and menu-bar settings
4. Compact Battery Settings card and Drawstate Direct information page
5. About and acknowledgments
