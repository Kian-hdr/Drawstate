# App Review Notes for 1.0.1 (Build 2)

These notes describe the Mac App Store binary for version 1.0.1, build 2.

## App behavior

Drawstate is a menu-bar-only battery and power telemetry utility. `LSUIElement` is enabled, so it intentionally has no Dock icon or main application window. Launch the app, then click its battery item in the macOS menu bar to open the popover. Settings are contained inside that popover.

The app works locally and has no account, analytics, cloud service, network client, or in-app purchase. It reads IOPowerSources and read-only IOKit registry power telemetry, and uses `SMAppService.mainApp` only when the user enables launch at login.

If a connected USB HID/UPS power bank publishes a standard external UPS power-source dictionary with usable telemetry, the overview conditionally shows a Power Bank card. The implementation uses documented IOPowerSources keys and public USB descriptor properties. USB identity enumeration only runs after a compatible UPS source exists. It does not open or control the USB device, parse arbitrary vendor data, or infer telemetry from an ordinary charger. The binary declares `com.apple.security.device.usb` for this read-only USB identity access.

## Charge-limit boundary

This Mac App Store binary is compiled with `APP_STORE`. It reads properties from the system AppleSmartBattery IORegistry service to provide its core live wattage and power-flow display. It does not open an IOKit user client or write battery state. It contains no undocumented charge-limit writer, Swift bridge, `pmset` or `launchctl` execution, legacy LaunchAgent migration, privileged helper, administrator request, downloaded code, or experimental charge-limit control.

The compact Battery Settings card shows the current energy mode. **Open Battery Settings** opens the system Battery settings pane. It does not present a disabled or simulated charge-limit control.

The card's **Charge-limit controls** row opens an in-app informational page describing Drawstate Direct's GitHub Releases and Homebrew options. Clicking the displayed Homebrew command only copies that text to the pasteboard. Its single **Open installation guide…** button opens the public repository's installation documentation in the default browser. It does not download or execute software, invoke Homebrew, present an installer, or replace the App Store application.

## Review checklist

- Confirm the submitted binary has the App Sandbox entitlement.
- Confirm the bundle identifier and provisioning profile match the App Store Connect record.
- Confirm the charge-limit bridge and all charge-limit writing symbols are absent from the executable.
- Test the menu-bar popover on battery and while connected to a charger.
- If available, connect a standards-compliant USB HID/UPS device and confirm the conditional Power Bank card. With no compatible device, confirm the overview is unchanged.
- Test the Battery Settings deep link and the documentation link.
- Explain any telemetry shown as `—` on the review Mac as hardware availability, not an app failure.
