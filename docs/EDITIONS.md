# Drawstate Editions

Drawstate is maintained as two separately packaged editions from one source tree.

| Capability | Drawstate Direct | Mac App Store |
| --- | --- | --- |
| Distribution | GitHub Releases and Homebrew | Mac App Store after approval |
| App Sandbox | No | Yes |
| Battery percentage, voltage, current, and time estimates | Yes | Yes, hardware-dependent |
| Charger capability | Yes | Yes, when IOPowerSources reports it |
| Detailed AppleSmartBattery and power-controller telemetry | Yes, hardware-dependent | Yes, read-only and hardware-dependent |
| Current configured charge limit | Experimental system telemetry | Unavailable through a documented public API |
| Charge-limit writing | Optional experimental control | Completely excluded at compile time |
| Swift charge-limit bridge | Bundled | Not compiled or bundled |
| Battery Settings shortcut | Yes | Yes |
| Compatible USB HID/UPS power-bank telemetry | Yes | Yes, through public APIs and the USB sandbox entitlement |

## Compile-time boundary

The Mac App Store build passes `-DAPP_STORE` to Swift. Both editions use the same read-only IOKit telemetry so Drawstate's core live-wattage experience remains intact. Code under `#if !APP_STORE` excludes:

- `ChargeLimitController` and all experimental control UI
- `ChargeLimitBridge.swift`
- `pmset` process execution and charge-limit parsing at runtime
- Direct's legacy LaunchAgent migration and `launchctl` process execution

The App Store app includes a compact Drawstate Direct row inside Battery Settings. It opens an in-app explanation of the GitHub Releases and Homebrew options. The Homebrew command can be copied to the clipboard, and the page's single external action opens the official [README installation section](https://github.com/Kian-hdr/Drawstate#install). It does not download, install, execute, or replace software.

## Store telemetry boundary

The sandboxed edition uses IOPowerSources plus read-only IOKit registry properties from the system AppleSmartBattery service. It does not open an IOKit user client or write battery state. Some service names and properties are not separately documented as a stable high-level API, so App Review may require this implementation to change.

The configured charge-limit value, charge-limit writing, and High Power mode parsing remain Direct-only. Other measurements remain hardware-dependent and display `—` when unavailable. Drawstate never presents a missing measurement as zero.

Power-bank support has the same implementation in both editions. It accepts standard external UPS descriptions from IOPowerSources and uses public IOKit USB descriptor properties only to enrich identity. It does not parse arbitrary vendor data, open USB interfaces, send device commands, or infer a power bank from a charger. Future documented vendor integrations must conform to the isolated provider protocols.
