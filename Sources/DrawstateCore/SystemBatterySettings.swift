import Foundation

public enum EnergyMode: String, Equatable, Sendable {
    case lowPower = "Low Power"
    case automatic = "Automatic"
    case highPower = "High Power"
}

public struct SystemBatterySettingsSnapshot: Equatable, Sendable {
    public var energyMode: EnergyMode?
    public var highPowerModeSupported: Bool?
    public var chargeLimitPercent: Int?

    public init(
        energyMode: EnergyMode? = nil,
        highPowerModeSupported: Bool? = nil,
        chargeLimitPercent: Int? = nil
    ) {
        self.energyMode = energyMode
        self.highPowerModeSupported = highPowerModeSupported
        self.chargeLimitPercent = chargeLimitPercent
    }
}

public enum SystemBatterySettingsParser {
    public static let allowedChargeLimits = [80, 85, 90, 95, 100]

    public static func snapshot(
        activePowerSettings: String,
        batteryLimitSettings: String,
        lowPowerModeEnabled: Bool
    ) -> SystemBatterySettingsSnapshot {
        let normalized = activePowerSettings.lowercased()
        let exposesLowPower = value(named: "lowpowermode", in: normalized) != nil
        let highPowerValue = value(named: "highpowermode", in: normalized)

        let mode: EnergyMode?
        if lowPowerModeEnabled || value(named: "lowpowermode", in: normalized) == 1 {
            mode = .lowPower
        } else if highPowerValue == 1 {
            mode = .highPower
        } else if exposesLowPower || highPowerValue != nil {
            mode = .automatic
        } else {
            mode = nil
        }

        return SystemBatterySettingsSnapshot(
            energyMode: mode,
            highPowerModeSupported: highPowerValue != nil,
            chargeLimitPercent: chargeLimit(in: batteryLimitSettings)
        )
    }

    public static func chargeLimit(in output: String) -> Int? {
        guard let value = firstCapture(
            pattern: #"chargeSocLimitSoc\s*=\s*(\d+)"#,
            in: output
        ), let limit = Int(value), allowedChargeLimits.contains(limit) else {
            return nil
        }
        return limit
    }

    private static func value(named name: String, in output: String) -> Int? {
        guard let captured = firstCapture(
            pattern: "(?m)^\\s*\(NSRegularExpression.escapedPattern(for: name))\\s+(\\d+)\\s*$",
            in: output
        ) else { return nil }
        return Int(captured)
    }

    private static func firstCapture(pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              match.numberOfRanges > 1,
              let captureRange = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return String(text[captureRange])
    }
}
