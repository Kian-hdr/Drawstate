import Foundation

public enum PowerState: String, Sendable {
    case battery = "On Battery"
    case charging = "Charging"
    case paused = "Charging Paused"
    case full = "Fully Charged"
    case external = "External Power"
    case unavailable = "Unavailable"
}

public enum EstimateSource: String, Sendable {
    case system = "macOS estimate"
    case calculated = "Drawstate estimate"
}

public struct RuntimeEstimate: Equatable, Sendable {
    public let seconds: TimeInterval
    public let source: EstimateSource

    public init(seconds: TimeInterval, source: EstimateSource) {
        self.seconds = seconds
        self.source = source
    }
}

public struct PowerSample: Sendable {
    public var timestamp = Date()
    public var state: PowerState = .unavailable
    public var externalConnected = false
    public var isCharging = false
    public var fullyCharged = false

    public var batteryPercent: Double?
    public var systemLoadWatts: Double?
    public var wallInputWatts: Double?
    public var adapterContributionWatts: Double?
    /// Positive means charging the battery; negative means the battery is supplying power.
    public var batteryFlowWatts: Double?

    public var voltageVolts: Double?
    public var currentAmps: Double?
    public var adapterRatedWatts: Double?
    public var cycleCount: Int?
    public var healthPercent: Double?

    public var rawCurrentCapacityMAh: Double?
    public var rawMaxCapacityMAh: Double?
    public var systemTimeToFullMinutes: Double?
    public var systemTimeToEmptyMinutes: Double?

    public init() {}
}

public enum PowerFormatting {
    public static func roundedPercent(_ value: Double?) -> Int? {
        guard let value, value.isFinite else { return nil }
        return Int(min(100, max(0, value)).rounded())
    }

    public static func percent(_ value: Double?) -> String {
        guard let value = roundedPercent(value) else { return "—%" }
        return "\(value)%"
    }

    public static func watts(_ value: Double?) -> String {
        guard let value, value.isFinite else { return "—" }
        let magnitude = abs(value)
        return magnitude < 10
            ? String(format: "%.1f W", magnitude)
            : String(format: "%.0f W", magnitude)
    }

    public static func compactWatts(_ value: Double?) -> String {
        watts(value).replacingOccurrences(of: " W", with: "W")
    }

    public static func directionalWatts(
        _ value: Double?,
        receiving: Bool,
        compact: Bool
    ) -> String {
        guard let value, value.isFinite else { return "—" }
        let sign = receiving ? "+" : "−"
        return sign + (compact ? compactWatts(value) : watts(value))
    }

    public static func runtime(_ estimate: RuntimeEstimate?) -> String {
        guard let estimate, estimate.seconds.isFinite, estimate.seconds >= 60 else {
            return "Calculating…"
        }
        let totalMinutes = Int(estimate.seconds / 60.0)
        let days = totalMinutes / 1_440
        let hours = (totalMinutes % 1_440) / 60
        let minutes = totalMinutes % 60
        if days > 0 { return hours > 0 ? "\(days)d \(hours)h" : "\(days)d" }
        if hours > 0 { return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h" }
        return "\(minutes)m"
    }

    public static func compactRuntime(_ estimate: RuntimeEstimate?) -> String {
        runtime(estimate).replacingOccurrences(of: " ", with: "")
    }

    public static func menuTitle(parts: [String], compact: Bool) -> String {
        parts.joined(separator: compact ? " " : " · ")
    }

    public static func temporaryStatusIsVisible(
        since startedAt: Date,
        now: Date,
        duration: TimeInterval = 4
    ) -> Bool {
        now.timeIntervalSince(startedAt) < duration
    }
}
