# Suggested App Review Notes

Use these notes as a starting point when an App Store Connect record and review submission are prepared. Update the version and any reviewer instructions before submitting.

## App behavior

Drawstate is a menu-bar-only battery and power telemetry utility. `LSUIElement` is enabled, so it intentionally has no Dock icon or main application window. Launch the app, then click its battery item in the macOS menu bar to open the popover. Settings are contained inside that popover.

The app works locally and has no account, analytics, cloud service, network client, or in-app purchase. It reads documented IOPowerSources data and uses `SMAppService.mainApp` only when the user enables launch at login.

## Charge-limit boundary

This Mac App Store binary is compiled with `APP_STORE`. It contains no AppleSmartBattery IORegistry access, undocumented charge-limit writer, Swift bridge, `pmset` execution, privileged helper, administrator request, downloaded code, or experimental charge-limit control.

The Battery Settings card shows `—` for the configured charge limit because macOS does not expose that value through a documented public API. **Open Battery Settings** opens the system Battery settings pane.

The separate Drawstate Direct information card has one **Learn about Drawstate Direct…** button. It opens the public repository's installation documentation in the default browser. It does not download or execute software, invoke Homebrew, present an installer, or replace the App Store application.

## Review checklist

- Confirm the submitted binary has the App Sandbox entitlement.
- Confirm the bundle identifier and provisioning profile match the App Store Connect record.
- Confirm the charge-limit bridge is absent from the bundle and Direct-only symbols are absent from the executable.
- Test the menu-bar popover on battery and while connected to a charger.
- Test the Battery Settings deep link and the documentation link.
- Explain any telemetry shown as `—` on the review Mac as hardware or public-API availability, not an app failure.
