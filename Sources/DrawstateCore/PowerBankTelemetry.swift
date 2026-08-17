import Foundation

public enum PowerBankState: String, Sendable {
    case charging = "Charging"
    case discharging = "Discharging"
    case full = "Full"
    case idle = "Connected"
}

public enum PowerBankTelemetrySource: String, Sendable {
    case powerSources = "macOS power source"
    case hidUPS = "USB HID/UPS"
    case documentedVendor = "Vendor interface"
}

/// A battery-backed external power source. This model is intentionally separate from
/// `PowerSample` so an external UPS or power bank can never be mistaken for the Mac battery.
public struct PowerBankSample: Equatable, Sendable {
    public var id: String
    public var name: String
    public var model: String?
    public var vendorID: Int?
    public var productID: Int?
    public var serialNumber: String?
    public var state: PowerBankState
    public var remainingPercent: Double?
    public var voltageVolts: Double?
    public var currentAmps: Double?
    public var outputWatts: Double?
    public var timeToEmpty: RuntimeEstimate?
    public var estimatedPercentAtMacTarget: Double?
    public var source: PowerBankTelemetrySource
    public var timestamp: Date

    public init(
        id: String,
        name: String,
        model: String? = nil,
        vendorID: Int? = nil,
        productID: Int? = nil,
        serialNumber: String? = nil,
        state: PowerBankState,
        remainingPercent: Double? = nil,
        voltageVolts: Double? = nil,
        currentAmps: Double? = nil,
        outputWatts: Double? = nil,
        timeToEmpty: RuntimeEstimate? = nil,
        estimatedPercentAtMacTarget: Double? = nil,
        source: PowerBankTelemetrySource,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.model = model
        self.vendorID = vendorID
        self.productID = productID
        self.serialNumber = serialNumber
        self.state = state
        self.remainingPercent = remainingPercent
        self.voltageVolts = voltageVolts
        self.currentAmps = currentAmps
        self.outputWatts = outputWatts
        self.timeToEmpty = timeToEmpty
        self.estimatedPercentAtMacTarget = estimatedPercentAtMacTarget
        self.source = source
        self.timestamp = timestamp
    }

    public var hasUsableTelemetry: Bool {
        remainingPercent != nil || voltageVolts != nil || currentAmps != nil ||
            outputWatts != nil || timeToEmpty != nil
    }
}

public enum PowerBankParser {
    /// Parses dictionaries returned by `IOPSGetPowerSourceDescription`. Only the documented
    /// external UPS type is accepted; internal batteries and ordinary adapters are rejected.
    public static func powerSource(
        _ dictionary: [String: Any],
        now: Date = Date()
    ) -> PowerBankSample? {
        guard (dictionary["Type"] as? String) == "UPS",
              ((dictionary["Is Present"] as? NSNumber)?.boolValue ?? true),
              (dictionary["Power Source State"] as? String) != "Off Line"
        else { return nil }

        let currentCapacity = finiteNonnegative(dictionary["Current Capacity"])
        let maxCapacity = finitePositive(dictionary["Max Capacity"])
        let percent: Double? = {
            guard let currentCapacity, let maxCapacity else { return nil }
            let value = currentCapacity / maxCapacity * 100
            return value.isFinite ? min(100, max(0, value)) : nil
        }()

        let isCharging = (dictionary["Is Charging"] as? NSNumber)?.boolValue ?? false
        let isCharged = (dictionary["Is Charged"] as? NSNumber)?.boolValue ?? false
        let sourceState = dictionary["Power Source State"] as? String
        let state: PowerBankState = isCharged ? .full
            : isCharging ? .charging
            : sourceState == "Battery Power" ? .discharging
            : .idle

        let voltage = publicVoltage(dictionary["Voltage"])
        let current = publicCurrent(dictionary["Current"])
        let output = state == .discharging
            ? voltage.flatMap { volts in current.map { abs(volts * $0) } }
            : nil
        let minutes = validMinutes(dictionary["Time to Empty"])
        let runtime = minutes.map {
            RuntimeEstimate(seconds: $0 * 60, source: .system)
        }

        let powerSourceID = integer(dictionary["Power Source ID"]).map(String.init)
        let serial = cleanString(dictionary["Hardware Serial Number"])
        let vendorID = integer(dictionary["Vendor ID"])
        let productID = integer(dictionary["Product ID"])
        let id = powerSourceID ?? serial ?? [vendorID, productID]
            .compactMap { $0.map(String.init) }
            .joined(separator: ":")
        guard !id.isEmpty else { return nil }

        let name = cleanString(dictionary["Name"]) ?? "Power Bank"
        let transport = dictionary["Transport Type"] as? String
        var result = PowerBankSample(
            id: "iops:\(id)",
            name: name,
            vendorID: vendorID,
            productID: productID,
            serialNumber: serial,
            state: state,
            remainingPercent: percent,
            voltageVolts: voltage,
            currentAmps: current,
            outputWatts: output,
            timeToEmpty: runtime,
            source: transport == "USB" ? .hidUPS : .powerSources,
            timestamp: now
        )
        guard result.hasUsableTelemetry else { return nil }
        result.remainingPercent = result.remainingPercent.flatMap(validPercent)
        return result
    }

    public static func visible(
        _ candidates: [PowerBankSample],
        now: Date = Date(),
        maximumAge: TimeInterval = 5
    ) -> [PowerBankSample] {
        candidates.filter { sample in
            let age = now.timeIntervalSince(sample.timestamp)
            return sample.hasUsableTelemetry && age >= -1 && age <= maximumAge
        }
    }

    public static func preferred(
        _ candidates: [PowerBankSample],
        now: Date = Date(),
        maximumAge: TimeInterval = 5
    ) -> PowerBankSample? {
        visible(candidates, now: now, maximumAge: maximumAge)
            .sorted { lhs, rhs in
                let lhsRank = stateRank(lhs.state)
                let rhsRank = stateRank(rhs.state)
                if lhsRank != rhsRank { return lhsRank > rhsRank }
                if lhs.outputWatts != rhs.outputWatts {
                    return (lhs.outputWatts ?? -1) > (rhs.outputWatts ?? -1)
                }
                return lhs.id < rhs.id
            }
            .first
    }

    private static func stateRank(_ state: PowerBankState) -> Int {
        switch state {
        case .discharging: return 3
        case .charging: return 2
        case .full: return 1
        case .idle: return 0
        }
    }

    private static func finitePositive(_ value: Any?) -> Double? {
        guard let number = value as? NSNumber else { return nil }
        let value = number.doubleValue
        return value.isFinite && value > 0 ? value : nil
    }

    private static func finiteNonnegative(_ value: Any?) -> Double? {
        guard let number = value as? NSNumber else { return nil }
        let value = number.doubleValue
        return value.isFinite && value >= 0 ? value : nil
    }

    private static func integer(_ value: Any?) -> Int? {
        guard let number = value as? NSNumber else { return nil }
        return number.intValue
    }

    private static func cleanString(_ value: Any?) -> String? {
        guard let value = value as? String else { return nil }
        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? nil : cleaned
    }

    private static func publicVoltage(_ value: Any?) -> Double? {
        finitePositive(value).flatMap { millivolts in
            let volts = millivolts / 1_000
            return (volts >= 1 && volts <= 100) ? volts : nil
        }
    }

    private static func publicCurrent(_ value: Any?) -> Double? {
        guard let number = value as? NSNumber else { return nil }
        let milliamps = Int64(bitPattern: number.uint64Value)
        guard abs(Double(milliamps)) < 100_000 else { return nil }
        let amps = Double(milliamps) / 1_000
        return amps.isFinite ? amps : nil
    }

    private static func validMinutes(_ value: Any?) -> Double? {
        guard let number = value as? NSNumber else { return nil }
        let minutes = number.doubleValue
        return minutes.isFinite && minutes >= 1 && minutes < 60 * 24 * 30 ? minutes : nil
    }

    private static func validPercent(_ value: Double) -> Double? {
        value.isFinite && value >= 0 && value <= 100 ? value : nil
    }
}

public enum PowerBankEstimator {
    /// Linear estimate based on the bank's currently reported runtime and present load.
    public static func percentAtMacTarget(
        currentPercent: Double?,
        powerBankRuntime: RuntimeEstimate?,
        macRuntime: RuntimeEstimate?
    ) -> Double? {
        guard let currentPercent,
              let powerBankSeconds = powerBankRuntime?.seconds,
              let macSeconds = macRuntime?.seconds,
              currentPercent.isFinite,
              powerBankSeconds.isFinite,
              macSeconds.isFinite,
              currentPercent >= 0,
              currentPercent <= 100,
              powerBankSeconds >= 60,
              macSeconds >= 0
        else { return nil }
        return min(100, max(0, currentPercent * (1 - macSeconds / powerBankSeconds)))
    }
}

/// Percentage-slope fallback used only when the device does not publish a runtime. It requires
/// a meaningful observation window and labels its result as a Drawstate estimate.
public struct PowerBankRuntimeEstimator {
    private var observations: [(date: Date, percent: Double)] = []
    private let minimumObservationTime: TimeInterval
    private let minimumPercentDrop: Double
    private let maximumObservationTime: TimeInterval

    public init(
        minimumObservationTime: TimeInterval = 30,
        minimumPercentDrop: Double = 0.2,
        maximumObservationTime: TimeInterval = 10 * 60
    ) {
        self.minimumObservationTime = max(1, minimumObservationTime)
        self.minimumPercentDrop = max(0.01, minimumPercentDrop)
        self.maximumObservationTime = max(minimumObservationTime, maximumObservationTime)
    }

    public mutating func reset() {
        observations.removeAll(keepingCapacity: true)
    }

    public mutating func estimate(for sample: PowerBankSample) -> RuntimeEstimate? {
        guard sample.state == .discharging,
              let percent = sample.remainingPercent,
              percent.isFinite,
              percent >= 0,
              percent <= 100
        else {
            reset()
            return nil
        }

        observations.append((sample.timestamp, percent))
        let cutoff = sample.timestamp.addingTimeInterval(-maximumObservationTime)
        observations.removeAll { $0.date < cutoff }
        guard let first = observations.first else { return nil }
        let elapsed = sample.timestamp.timeIntervalSince(first.date)
        let drop = first.percent - percent
        guard elapsed >= minimumObservationTime, drop >= minimumPercentDrop else { return nil }
        let percentPerSecond = drop / elapsed
        guard percentPerSecond > 0 else { return nil }
        let seconds = percent / percentPerSecond
        guard seconds.isFinite, seconds >= 60, seconds < 60 * 60 * 24 * 30 else { return nil }
        return RuntimeEstimate(seconds: seconds, source: .calculated)
    }
}
