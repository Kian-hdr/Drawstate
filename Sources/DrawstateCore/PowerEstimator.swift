import Foundation

public struct RollingMedian {
    private var values: [Double] = []
    private let capacity: Int

    public init(capacity: Int = 5) {
        self.capacity = max(1, capacity)
    }

    public mutating func add(_ value: Double?) -> Double? {
        guard let value, value.isFinite else { return median }
        values.append(value)
        if values.count > capacity { values.removeFirst(values.count - capacity) }
        return median
    }

    public mutating func reset() { values.removeAll(keepingCapacity: true) }

    public var median: Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        return sorted.count.isMultiple(of: 2)
            ? (sorted[middle - 1] + sorted[middle]) / 2
            : sorted[middle]
    }
}

public struct RuntimeEstimator {
    private var batteryPowerSamples: [Double] = []
    private var previousExternalState: Bool?
    private let minimumSamples: Int
    private let forcedEstimateSamples: Int
    private let maximumSamples: Int
    private let stabilityTolerance: Double

    public init(
        minimumSamples: Int = 4,
        maximumSamples: Int = 60,
        forcedEstimateSamples: Int = 8,
        stabilityTolerance: Double = 0.35
    ) {
        self.minimumSamples = max(1, minimumSamples)
        self.maximumSamples = max(self.minimumSamples, maximumSamples)
        self.forcedEstimateSamples = min(
            self.maximumSamples,
            max(self.minimumSamples, forcedEstimateSamples)
        )
        self.stabilityTolerance = max(0, stabilityTolerance)
    }

    public mutating func reset() {
        batteryPowerSamples.removeAll(keepingCapacity: true)
        previousExternalState = nil
    }

    public mutating func estimate(for sample: PowerSample) -> RuntimeEstimate? {
        if previousExternalState != nil, previousExternalState != sample.externalConnected {
            batteryPowerSamples.removeAll(keepingCapacity: true)
        }
        previousExternalState = sample.externalConnected

        if sample.externalConnected,
           let minutes = sample.systemTimeToFullMinutes {
            append(sample.batteryFlowWatts)
            return RuntimeEstimate(seconds: minutes * 60, source: .system)
        }
        if !sample.externalConnected,
           let minutes = sample.systemTimeToEmptyMinutes {
            append(sample.batteryFlowWatts)
            return RuntimeEstimate(seconds: minutes * 60, source: .system)
        }

        append(sample.batteryFlowWatts)
        guard batteryPowerSamples.count >= minimumSamples,
              let current = sample.rawCurrentCapacityMAh,
              let maximum = sample.rawMaxCapacityMAh,
              let voltage = sample.voltageVolts
        else { return nil }

        let recentWindow = Array(batteryPowerSamples.suffix(forcedEstimateSamples))
        let magnitudes = recentWindow.map(abs).filter { $0 >= 0.5 }
        guard magnitudes.count >= minimumSamples else { return nil }

        let usablePower = median(of: magnitudes)
        guard usablePower >= 0.5 else { return nil }
        let largestRelativeDeviation = magnitudes
            .map { abs($0 - usablePower) / usablePower }
            .max() ?? 0
        let stable = largestRelativeDeviation <= stabilityTolerance
        guard stable || batteryPowerSamples.count >= forcedEstimateSamples else { return nil }

        let capacityMAh = sample.externalConnected ? max(0, maximum - current) : max(0, current)
        let energyWh = capacityMAh * voltage / 1_000.0
        let seconds = energyWh / usablePower * 3_600
        guard seconds.isFinite, seconds >= 60, seconds < 60 * 60 * 24 * 30 else { return nil }
        return RuntimeEstimate(seconds: seconds, source: .calculated)
    }

    private mutating func append(_ power: Double?) {
        guard let power, power.isFinite else { return }
        batteryPowerSamples.append(power)
        if batteryPowerSamples.count > maximumSamples {
            batteryPowerSamples.removeFirst(batteryPowerSamples.count - maximumSamples)
        }
    }

    private func median(of values: [Double]) -> Double {
        let sorted = values.sorted()
        let middle = sorted.count / 2
        return sorted.count.isMultiple(of: 2)
            ? (sorted[middle - 1] + sorted[middle]) / 2
            : sorted[middle]
    }
}
