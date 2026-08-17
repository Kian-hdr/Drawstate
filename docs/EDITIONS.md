# Drawstate Editions

Drawstate is maintained as two separately packaged editions from one source tree.

| Capability | Drawstate Direct | Mac App Store |
| --- | --- | --- |
| Distribution | GitHub Releases and Homebrew | Mac App Store after approval |
| App Sandbox | No | Yes |
| Battery percentage, voltage, current, and time estimates | Yes | Yes, through public IOPowerSources APIs |
| Charger capability | Yes | Yes, when IOPowerSources reports it |
| Detailed AppleSmartBattery and power-controller telemetry | Yes, hardware-dependent | No |
| Current configured charge limit | Experimental system telemetry | Unavailable through a documented public API |
| Charge-limit writing | Optional experimental control | Completely excluded at compile time |
| Swift charge-limit bridge | Bundled | Not compiled or bundled |
| Battery Settings shortcut | Yes | Yes |

## Compile-time boundary

The Mac App Store build passes `-DAPP_STORE` to Swift. Code under `#if !APP_STORE` is not compiled into that executable. This boundary excludes:

- `ChargeLimitController` and all experimental control UI
- `ChargeLimitBridge.swift`
- AppleSmartBattery IORegistry reads and `PowerTelemetryData`
- `pmset` process execution and charge-limit parsing at runtime

The App Store app includes a secondary Drawstate Direct card. Its single action opens the official [README installation section](https://github.com/Kian-hdr/Drawstate#install). It does not download, install, execute, or replace software.

## Store telemetry limitations

The sandboxed edition intentionally uses documented IOPowerSources data only. Depending on the Mac, it can show battery percentage, voltage, signed current, derived battery power, system time until full or empty, charger rated watts, and capacity-based health.

The following Direct measurements are unavailable in the Store edition because their sources are undocumented or incompatible with the public-API boundary:

- true instantaneous adapter contribution and estimated wall input
- power-controller system load while connected to an adapter
- cycle count and raw-capacity fallback runtime
- the configured charge-limit value and High Power mode readout

Unavailable values remain `—`. Drawstate never presents a missing measurement as zero.
