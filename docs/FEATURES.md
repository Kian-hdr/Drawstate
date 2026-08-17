# Features

## Menu bar

- Battery percentage inside an Apple-style level-aware battery outline, or the original icon style
- Signed live wattage: positive while receiving adapter power and negative while drawing from the battery
- Time until full or empty, with a smoothed local fallback estimate
- Compact formatting and temporary-state hiding
- Native Command-drag positioning

Every menu element can be changed independently in Settings.

## Details panel

- Estimated wall input, adapter contribution, total Mac load, and battery flow
- Battery percentage, health, voltage, current, and cycle count
- Adapter capability
- Charging, paused, full, battery, and unavailable states
- Current macOS energy mode and charge-limit reading
- A conditional Power Bank card for compatible USB HID/UPS devices that report usable telemetry

The Power Bank card can show the reported name/model, remaining percentage, charging state, voltage, current, output wattage, time until empty, and the estimated power-bank percentage at the Mac's charge target. Calculated values are explicitly labeled as estimates. Unsupported and disconnected devices produce no card, placeholder, or menu-bar content.

Unavailable hardware telemetry is shown as `—`, never as a fabricated zero.

## Experimental charge-limit control

Users may opt in under **Settings > Experimental**. It supports 80%, 85%, 90%, 95%, and 100% on compatible macOS versions. Drawstate verifies every requested change. This feature uses an undocumented local macOS service and may stop working after an update. It does not use administrator access or raw SMC writes.
