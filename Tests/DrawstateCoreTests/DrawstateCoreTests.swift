import XCTest
@testable import DrawstateCore

final class DrawstateCoreTests: XCTestCase {
    func testWrappedNegativeTelemetryValue() {
        let wrapped = NSNumber(value: UInt64.max - 6_999)
        XCTAssertEqual(TelemetryValue.signedInt64(wrapped), -7_000)
#if !APP_STORE
        XCTAssertEqual(
            TelemetryValue.telemetryWatts(["BatteryPower": wrapped], key: "BatteryPower"),
            -7.0
        )
#endif
    }

    func testPublicPowerSourceElectricalValues() {
        let source: [String: Any] = [
            "Voltage": NSNumber(value: 12_000),
            "Current": NSNumber(value: -1_500)
        ]
        XCTAssertEqual(TelemetryValue.publicVoltageVolts(source), 12)
        XCTAssertEqual(TelemetryValue.publicCurrentAmps(source), -1.5)
        XCTAssertEqual(TelemetryValue.publicBatteryWatts(source), -18)
    }

    func testPublicBatteryHealthRejectsMismatchedCapacityScales() {
        XCTAssertEqual(
            TelemetryValue.publicHealthPercent([
                "Max Capacity": NSNumber(value: 4_500),
                "DesignCapacity": NSNumber(value: 5_000)
            ]),
            90
        )
        XCTAssertNil(TelemetryValue.publicHealthPercent([
            "Max Capacity": NSNumber(value: 80),
            "DesignCapacity": NSNumber(value: 5_000)
        ]))
    }

    func testRuntimeFormatting() {
        XCTAssertEqual(PowerFormatting.runtime(.init(seconds: 42 * 60, source: .system)), "42m")
        XCTAssertEqual(PowerFormatting.runtime(.init(seconds: 6 * 3_600 + 12 * 60, source: .system)), "6h 12m")
        XCTAssertEqual(PowerFormatting.runtime(.init(seconds: 28 * 3_600, source: .system)), "1d 4h")
        XCTAssertEqual(PowerFormatting.runtime(nil), "Calculating…")
        XCTAssertEqual(PowerFormatting.compactRuntime(.init(seconds: 6 * 3_600 + 12 * 60, source: .system)), "6h12m")
        XCTAssertEqual(PowerFormatting.compactRuntime(.init(seconds: 28 * 3_600, source: .system)), "1d4h")
        XCTAssertEqual(PowerFormatting.percent(68.4), "68%")
        XCTAssertEqual(PowerFormatting.percent(nil), "—%")
        XCTAssertEqual(PowerFormatting.roundedPercent(68.4), 68)
        XCTAssertEqual(PowerFormatting.roundedPercent(140), 100)
        XCTAssertEqual(PowerFormatting.roundedPercent(-4), 0)
        XCTAssertNil(PowerFormatting.roundedPercent(nil))
        XCTAssertEqual(PowerFormatting.compactWatts(7.4), "7.4W")
        XCTAssertEqual(PowerFormatting.compactWatts(42), "42W")
        XCTAssertEqual(PowerFormatting.directionalWatts(42, receiving: true, compact: true), "+42W")
        XCTAssertEqual(PowerFormatting.directionalWatts(7.4, receiving: false, compact: true), "−7.4W")
        XCTAssertEqual(PowerFormatting.directionalWatts(nil, receiving: true, compact: true), "—")
        XCTAssertEqual(PowerFormatting.menuTitle(parts: ["80%", "+42W", "1h18m"], compact: true), "80% +42W 1h18m")
        XCTAssertEqual(PowerFormatting.menuTitle(parts: ["80%", "+42 W", "1h 18m"], compact: false), "80% · +42 W · 1h 18m")

        let start = Date(timeIntervalSince1970: 1_000)
        XCTAssertTrue(PowerFormatting.temporaryStatusIsVisible(since: start, now: start.addingTimeInterval(3.99)))
        XCTAssertFalse(PowerFormatting.temporaryStatusIsVisible(since: start, now: start.addingTimeInterval(4)))
    }

    func testRollingMedianRejectsSpike() {
        var median = RollingMedian(capacity: 5)
        [7.0, 7.2, 40.0, 7.1, 6.9].forEach { _ = median.add($0) }
        XCTAssertEqual(median.median!, 7.1, accuracy: 0.001)
    }

    func testCalculatedBatteryRuntime() {
        var estimator = RuntimeEstimator(minimumSamples: 3, maximumSamples: 3, forcedEstimateSamples: 3)
        var sample = PowerSample()
        sample.externalConnected = false
        sample.batteryFlowWatts = -10
        sample.rawCurrentCapacityMAh = 5_000
        sample.rawMaxCapacityMAh = 6_000
        sample.voltageVolts = 12

        XCTAssertNil(estimator.estimate(for: sample))
        XCTAssertNil(estimator.estimate(for: sample))
        let estimate = estimator.estimate(for: sample)
        XCTAssertEqual(estimate?.source, .calculated)
        XCTAssertEqual(estimate!.seconds, 6 * 3_600, accuracy: 0.001)
    }

    func testStableRuntimeEstimateIsAvailableAfterFourSamples() {
        var estimator = RuntimeEstimator()
        var sample = PowerSample()
        sample.externalConnected = false
        sample.batteryFlowWatts = -10
        sample.rawCurrentCapacityMAh = 5_000
        sample.rawMaxCapacityMAh = 6_000
        sample.voltageVolts = 12

        XCTAssertNil(estimator.estimate(for: sample))
        XCTAssertNil(estimator.estimate(for: sample))
        XCTAssertNil(estimator.estimate(for: sample))
        XCTAssertNotNil(estimator.estimate(for: sample))
    }

    func testUnstableRuntimeEstimateWaitsUntilForcedThreshold() {
        var estimator = RuntimeEstimator()
        var sample = PowerSample()
        sample.externalConnected = false
        sample.rawCurrentCapacityMAh = 5_000
        sample.rawMaxCapacityMAh = 6_000
        sample.voltageVolts = 12

        for flow in [-5.0, -20, -6, -24, -7, -22, -8] {
            sample.batteryFlowWatts = flow
            XCTAssertNil(estimator.estimate(for: sample))
        }
        sample.batteryFlowWatts = -21
        XCTAssertNotNil(estimator.estimate(for: sample))
    }

    func testSystemEstimateHasPriority() {
        var estimator = RuntimeEstimator(minimumSamples: 1)
        var sample = PowerSample()
        sample.externalConnected = true
        sample.systemTimeToFullMinutes = 75
        sample.batteryFlowWatts = 20
        let estimate = estimator.estimate(for: sample)
        XCTAssertEqual(estimate, RuntimeEstimate(seconds: 4_500, source: .system))
    }

    func testInvalidSentinelIsUnavailable() {
#if !APP_STORE
        XCTAssertNil(TelemetryValue.telemetryWatts(["x": NSNumber(value: Int64.min)], key: "x"))
#endif
        XCTAssertEqual(PowerFormatting.watts(nil), "—")
    }

#if !APP_STORE
    func testWallEstimateReconcilesAdapterOutputAndLoss() {
        let telemetry: [String: Any] = [
            "SystemPowerIn": NSNumber(value: 29_801),
            "AdapterEfficiencyLoss": NSNumber(value: 735),
            "WallEnergyEstimate": NSNumber(value: 9_013)
        ]
        XCTAssertEqual(TelemetryValue.estimatedWallWatts(telemetry)!, 30.536, accuracy: 0.001)
    }
#endif

#if !APP_STORE
    func testSystemBatterySettingsParsing() {
        let automatic = SystemBatterySettingsParser.snapshot(
            activePowerSettings: """
             lowpowermode         0
             highpowermode        0
            """,
            batteryLimitSettings: """
            chargeSocLimitReason = manualChargeLimit;
            chargeSocLimitSoc = 85;
            """,
            lowPowerModeEnabled: false
        )
        XCTAssertEqual(automatic.energyMode, .automatic)
        XCTAssertEqual(automatic.highPowerModeSupported, true)
        XCTAssertEqual(automatic.chargeLimitPercent, 85)

        let lowPower = SystemBatterySettingsParser.snapshot(
            activePowerSettings: "lowpowermode 0",
            batteryLimitSettings: "chargeSocLimitSoc = 80;",
            lowPowerModeEnabled: true
        )
        XCTAssertEqual(lowPower.energyMode, .lowPower)
        XCTAssertEqual(lowPower.highPowerModeSupported, false)
        XCTAssertEqual(lowPower.chargeLimitPercent, 80)

        let highPower = SystemBatterySettingsParser.snapshot(
            activePowerSettings: "highpowermode 1",
            batteryLimitSettings: "chargeSocLimitSoc = 100;",
            lowPowerModeEnabled: false
        )
        XCTAssertEqual(highPower.energyMode, .highPower)
        XCTAssertEqual(highPower.chargeLimitPercent, 100)
    }

    func testInvalidChargeLimitIsUnavailable() {
        XCTAssertEqual(SystemBatterySettingsParser.allowedChargeLimits, [80, 85, 90, 95, 100])
        XCTAssertNil(SystemBatterySettingsParser.chargeLimit(in: ""))
        XCTAssertNil(SystemBatterySettingsParser.chargeLimit(in: "chargeSocLimitSoc = 75;"))
        XCTAssertNil(SystemBatterySettingsParser.chargeLimit(in: "chargeSocLimitSoc = 82;"))
        XCTAssertNil(SystemBatterySettingsParser.chargeLimit(in: "chargeSocLimitSoc = 101;"))
    }
#endif

    func testPopoverFitsCurrentAndCompactDisplays() {
        XCTAssertEqual(
            PopoverGeometry.fit(visibleWidth: 1_512, visibleHeight: 949),
            PopoverDimensions(width: 370, settingsHeight: 640)
        )
        XCTAssertEqual(
            PopoverGeometry.fit(visibleWidth: 340, visibleHeight: 500),
            PopoverDimensions(width: 292, settingsHeight: 428)
        )
    }
}
