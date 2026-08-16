import AppKit
import Combine
import Foundation
import IOKit.ps
import DrawstateCore

@MainActor
final class PowerMonitor: ObservableObject {
    @Published private(set) var sample = PowerSample()
    @Published private(set) var displayWatts: Double?
    @Published private(set) var runtime: RuntimeEstimate?
    @Published private(set) var batterySettings = SystemBatterySettingsSnapshot()

    private let reader = PowerTelemetryReader()
    private var wattSmoother = RollingMedian(capacity: 5)
    private var runtimeSmoother = RollingMedian(capacity: 7)
    private var estimator = RuntimeEstimator()
    private var timer: Timer?
    private var batterySettingsTimer: Timer?
    private var previousExternalState: Bool?
    private var powerSourceRunLoopSource: CFRunLoopSource?
    private var batterySettingsRefreshInFlight = false

    init() {
        refresh()
        refreshBatterySettings()
        installPowerSourceNotifications()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        timer?.tolerance = 0.12
        batterySettingsTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshBatterySettings() }
        }
        batterySettingsTimer?.tolerance = 1
        NotificationCenter.default.addObserver(
            forName: .NSProcessInfoPowerStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refreshBatterySettings() }
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.resetAndRefresh() }
        }
    }

    deinit {
        timer?.invalidate()
        batterySettingsTimer?.invalidate()
        if let powerSourceRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), powerSourceRunLoopSource, .defaultMode)
            CFRunLoopSourceInvalidate(powerSourceRunLoopSource)
        }
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    var menuTitle: String {
        let watts = PowerFormatting.watts(displayWatts)
        let time: String
        switch sample.state {
        case .full: time = "Full"
        case .paused: time = "Paused"
        case .external where !sample.isCharging: time = "Connected"
        case .unavailable: time = "Unavailable"
        default: time = PowerFormatting.runtime(runtime)
        }
        return "\(watts) · \(time)"
    }

    var menuIcon: String {
        switch sample.state {
        case .charging: return "bolt.fill"
        case .battery: return "battery.75percent"
        case .full: return "battery.100percent"
        case .paused, .external: return "powerplug.fill"
        case .unavailable: return "exclamationmark.triangle"
        }
    }

    var primaryRuntimeLabel: String {
        switch sample.state {
        case .charging: return "Until full"
        case .battery: return "Until empty"
        case .full: return "Battery"
        case .paused: return "Charging"
        default: return "Runtime"
        }
    }

    var primaryRuntimeValue: String {
        switch sample.state {
        case .full: return "Full"
        case .paused: return "Paused"
        default: return PowerFormatting.runtime(runtime)
        }
    }

    var runtimeSource: String {
        runtime?.source.rawValue ?? "Waiting for stable readings"
    }

    func refresh() {
        let newSample = reader.read()
        if let previousExternalState, previousExternalState != newSample.externalConnected {
            wattSmoother.reset()
            runtimeSmoother.reset()
            estimator.reset()
        }
        previousExternalState = newSample.externalConnected

        let menuPower: Double? = newSample.externalConnected
            ? (newSample.wallInputWatts ?? newSample.adapterContributionWatts ?? newSample.systemLoadWatts)
            : newSample.batteryFlowWatts.map(abs) ?? newSample.systemLoadWatts
        let useSmoothing = UserDefaults.standard.object(forKey: "smoothReadings") as? Bool ?? true
        displayWatts = useSmoothing ? wattSmoother.add(menuPower) : menuPower

        if let rawEstimate = estimator.estimate(for: newSample) {
            let seconds = useSmoothing
                ? (runtimeSmoother.add(rawEstimate.seconds) ?? rawEstimate.seconds)
                : rawEstimate.seconds
            runtime = RuntimeEstimate(seconds: seconds, source: rawEstimate.source)
        } else {
            runtime = nil
        }
        sample = newSample
    }

    func refreshBatterySettings() {
        guard !batterySettingsRefreshInFlight else { return }
        batterySettingsRefreshInFlight = true
        Task { [weak self] in
            let snapshot = await Task.detached(priority: .utility) {
                SystemBatterySettingsReader.read()
            }.value
            guard let self else { return }
            self.batterySettings = snapshot
            self.batterySettingsRefreshInFlight = false
        }
    }

    func refreshBatterySettingsNow() async {
        let snapshot = await Task.detached(priority: .userInitiated) {
            SystemBatterySettingsReader.read()
        }.value
        batterySettings = snapshot
        batterySettingsRefreshInFlight = false
    }

    private func resetAndRefresh() {
        wattSmoother.reset()
        runtimeSmoother.reset()
        estimator.reset()
        refresh()
    }

    private func installPowerSourceNotifications() {
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let unmanagedSource = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else { return }
            let monitor = Unmanaged<PowerMonitor>.fromOpaque(context).takeUnretainedValue()
            Task { @MainActor in
                monitor.refresh()
            }
        }, context) else { return }

        let source = unmanagedSource.takeRetainedValue()
        powerSourceRunLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
    }
}

private enum SystemBatterySettingsReader {
    static func read() -> SystemBatterySettingsSnapshot {
        SystemBatterySettingsParser.snapshot(
            activePowerSettings: runPMSet(arguments: ["-g"]),
            batteryLimitSettings: runPMSet(arguments: ["-g", "battlimit"]),
            lowPowerModeEnabled: ProcessInfo.processInfo.isLowPowerModeEnabled
        )
    }

    private static func runPMSet(arguments: [String]) -> String {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return "" }
            return String(
                data: pipe.fileHandleForReading.readDataToEndOfFile(),
                encoding: .utf8
            ) ?? ""
        } catch {
            return ""
        }
    }
}
