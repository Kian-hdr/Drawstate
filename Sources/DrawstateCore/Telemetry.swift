import Foundation
#if !APP_STORE
import IOKit
#endif
import IOKit.ps

public enum TelemetryValue {
    /// IORegistry occasionally exposes negative signed counters as wrapped UInt64 values.
    public static func signedInt64(_ value: Any?) -> Int64? {
        guard let number = value as? NSNumber else { return nil }
        return Int64(bitPattern: number.uint64Value)
    }

    public static func positiveDouble(_ value: Any?) -> Double? {
        guard let number = value as? NSNumber else { return nil }
        let result = number.doubleValue
        return result.isFinite && result > 0 ? result : nil
    }

#if !APP_STORE
    public static func telemetryWatts(_ dictionary: [String: Any], key: String) -> Double? {
        guard let raw = signedInt64(dictionary[key]) else { return nil }
        // INT64_MIN and common firmware sentinels must never appear as measurements.
        guard raw != Int64.min, abs(Double(raw)) < 1_000_000 else { return nil }
        return Double(raw) / 1_000.0
    }

    /// Estimates wall-side draw from adapter output plus the adapter efficiency loss reported
    /// by the power controller. `WallEnergyEstimate` is intentionally not used: on current
    /// Apple Silicon hardware it is an energy-estimation signal, not instantaneous wall watts.
    public static func estimatedWallWatts(_ dictionary: [String: Any]) -> Double? {
        guard let adapterOutput = telemetryWatts(dictionary, key: "SystemPowerIn"), adapterOutput >= 0 else {
            return nil
        }
        let efficiencyLoss = telemetryWatts(dictionary, key: "AdapterEfficiencyLoss") ?? 0
        return adapterOutput + max(0, efficiencyLoss)
    }
#endif

    /// Reads the documented IOPowerSources voltage key, expressed in millivolts.
    public static func publicVoltageVolts(_ dictionary: [String: Any]) -> Double? {
        positiveDouble(dictionary["Voltage"]).map { $0 / 1_000.0 }
    }

    /// Reads the documented signed IOPowerSources current key, expressed in milliamps.
    public static func publicCurrentAmps(_ dictionary: [String: Any]) -> Double? {
        guard let milliamps = signedInt64(dictionary["Current"]),
              abs(Double(milliamps)) < 100_000 else {
            return nil
        }
        return Double(milliamps) / 1_000.0
    }

    public static func publicBatteryWatts(_ dictionary: [String: Any]) -> Double? {
        guard let voltage = publicVoltageVolts(dictionary),
              let current = publicCurrentAmps(dictionary) else {
            return nil
        }
        return voltage * current
    }

    public static func publicHealthPercent(_ dictionary: [String: Any]) -> Double? {
        guard let maximum = positiveDouble(dictionary["Max Capacity"]),
              let design = positiveDouble(dictionary["DesignCapacity"]) else {
            return nil
        }
        let ratio = maximum / design
        guard ratio >= 0.3, ratio <= 1.2 else { return nil }
        return min(100, ratio * 100)
    }
}

public struct PowerTelemetryReader {
    public init() {}

    public func read() -> PowerSample {
        var sample = PowerSample()
        applyPowerSource(to: &sample)
#if !APP_STORE
        applySmartBattery(to: &sample)
#endif
        sample.state = state(for: sample)
        return sample
    }

    private func applyPowerSource(to sample: inout PowerSample) {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef]
        else { return }

        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue()
                    as? [String: Any],
                  (description["Type"] as? String) == "InternalBattery"
            else { continue }

            let sourceState = description["Power Source State"] as? String
            sample.externalConnected = sourceState == "AC Power"
            sample.isCharging = (description["Is Charging"] as? NSNumber)?.boolValue ?? false
            sample.fullyCharged = (description["Is Charged"] as? NSNumber)?.boolValue ?? false

            if let current = TelemetryValue.positiveDouble(description["Current Capacity"]),
               let maximum = TelemetryValue.positiveDouble(description["Max Capacity"]) {
                sample.batteryPercent = min(100, max(0, current / maximum * 100))
            }
            sample.voltageVolts = TelemetryValue.publicVoltageVolts(description)
            sample.currentAmps = TelemetryValue.publicCurrentAmps(description)
            sample.batteryFlowWatts = TelemetryValue.publicBatteryWatts(description)
            sample.healthPercent = TelemetryValue.publicHealthPercent(description)
            sample.systemTimeToFullMinutes = validMinutes(description["Time to Full Charge"])
            sample.systemTimeToEmptyMinutes = validMinutes(description["Time to Empty"])
            break
        }

        if sample.systemLoadWatts == nil, !sample.externalConnected,
           let batteryFlow = sample.batteryFlowWatts, batteryFlow < 0 {
            sample.systemLoadWatts = abs(batteryFlow)
        }
        if let adapter = IOPSCopyExternalPowerAdapterDetails()?.takeRetainedValue()
            as? [String: Any] {
            sample.adapterRatedWatts = TelemetryValue.positiveDouble(adapter["Watts"])
        }
    }

#if !APP_STORE
    private func applySmartBattery(to sample: inout PowerSample) {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return }
        defer { IOObjectRelease(service) }

        var unmanagedProperties: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &unmanagedProperties, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let properties = unmanagedProperties?.takeRetainedValue() as? [String: Any]
        else { return }

        sample.externalConnected = bool(properties["ExternalConnected"]) ?? sample.externalConnected
        sample.isCharging = bool(properties["IsCharging"]) ?? sample.isCharging
        sample.fullyCharged = bool(properties["FullyCharged"]) ?? sample.fullyCharged

        if let percent = TelemetryValue.positiveDouble(properties["CurrentCapacity"]) {
            sample.batteryPercent = min(100, percent)
        }

        let voltageMV = TelemetryValue.positiveDouble(properties["Voltage"])
            ?? TelemetryValue.positiveDouble(properties["AppleRawBatteryVoltage"])
        sample.voltageVolts = voltageMV.map { $0 / 1_000.0 } ?? sample.voltageVolts

        if let currentMA = TelemetryValue.signedInt64(properties["InstantAmperage"])
            ?? TelemetryValue.signedInt64(properties["Amperage"]),
           abs(Double(currentMA)) < 100_000 {
            sample.currentAmps = Double(currentMA) / 1_000.0
        }

        sample.rawCurrentCapacityMAh = TelemetryValue.positiveDouble(properties["AppleRawCurrentCapacity"])
        sample.rawMaxCapacityMAh = TelemetryValue.positiveDouble(properties["AppleRawMaxCapacity"])
        sample.cycleCount = TelemetryValue.signedInt64(properties["CycleCount"]).map(Int.init)

        if let currentMax = sample.rawMaxCapacityMAh,
           let design = TelemetryValue.positiveDouble(properties["DesignCapacity"]) {
            sample.healthPercent = min(100, max(0, currentMax / design * 100))
        }

        if let telemetry = properties["PowerTelemetryData"] as? [String: Any] {
            sample.systemLoadWatts = nonnegative(TelemetryValue.telemetryWatts(telemetry, key: "SystemLoad"))
            sample.adapterContributionWatts = nonnegative(TelemetryValue.telemetryWatts(telemetry, key: "SystemPowerIn"))
            sample.wallInputWatts = sample.externalConnected
                ? nonnegative(TelemetryValue.estimatedWallWatts(telemetry))
                : nil
            sample.batteryFlowWatts = TelemetryValue.telemetryWatts(telemetry, key: "BatteryPower")
        }

        if sample.batteryFlowWatts == nil,
           let voltage = sample.voltageVolts,
           let current = sample.currentAmps {
            sample.batteryFlowWatts = voltage * current
        }
        if sample.systemLoadWatts == nil, !sample.externalConnected,
           let batteryFlow = sample.batteryFlowWatts, batteryFlow < 0 {
            sample.systemLoadWatts = abs(batteryFlow)
        }

        sample.adapterRatedWatts = adapterWatts(in: properties) ?? sample.adapterRatedWatts
    }
#endif

    private func state(for sample: PowerSample) -> PowerState {
        if sample.externalConnected {
            if sample.fullyCharged { return .full }
            if sample.isCharging { return .charging }
            if sample.wallInputWatts != nil || sample.adapterContributionWatts != nil { return .paused }
            return .external
        }
        return sample.batteryPercent == nil ? .unavailable : .battery
    }

    private func validMinutes(_ value: Any?) -> Double? {
        guard let number = value as? NSNumber else { return nil }
        let minutes = number.doubleValue
        guard minutes > 0, minutes < 100_000 else { return nil }
        return minutes
    }

#if !APP_STORE
    private func bool(_ value: Any?) -> Bool? {
        (value as? NSNumber)?.boolValue
    }

    private func nonnegative(_ value: Double?) -> Double? {
        guard let value, value >= 0 else { return nil }
        return value
    }

    private func adapterWatts(in properties: [String: Any]) -> Double? {
        let candidates: [Any?] = {
            var values: [Any?] = []
            if let details = properties["AdapterDetails"] as? [String: Any] {
                values += [details["Watts"], details["Wattage"], details["AdapterPower"]]
            }
            if let raw = properties["AppleRawAdapterDetails"] as? [[String: Any]] {
                for details in raw {
                    values += [details["Watts"], details["Wattage"], details["AdapterPower"]]
                }
            }
            return values
        }()
        return candidates.compactMap(TelemetryValue.positiveDouble).first
    }
#endif
}
