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
        XCTAssertNil(TelemetryValue.telemetryWatts(["x": NSNumber(value: Int64.min)], key: "x"))
        XCTAssertEqual(PowerFormatting.watts(nil), "—")
    }

    func testWallEstimateReconcilesAdapterOutputAndLoss() {
        let telemetry: [String: Any] = [
            "SystemPowerIn": NSNumber(value: 29_801),
            "AdapterEfficiencyLoss": NSNumber(value: 735),
            "WallEnergyEstimate": NSNumber(value: 9_013)
        ]
        XCTAssertEqual(TelemetryValue.estimatedWallWatts(telemetry)!, 30.536, accuracy: 0.001)
    }

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

    func testUSBUPSPowerBankParsing() {
        let now = Date(timeIntervalSince1970: 10_000)
        let sample = PowerBankParser.powerSource([
            "Type": "UPS",
            "Transport Type": "USB",
            "Power Source ID": NSNumber(value: 42),
            "Name": "Example Power Bank",
            "Vendor ID": NSNumber(value: 1234),
            "Product ID": NSNumber(value: 5678),
            "Is Present": true,
            "Is Charging": false,
            "Is Charged": false,
            "Power Source State": "Battery Power",
            "Current Capacity": NSNumber(value: 72),
            "Max Capacity": NSNumber(value: 100),
            "Voltage": NSNumber(value: 20_000),
            "Current": NSNumber(value: -2_250),
            "Time to Empty": NSNumber(value: 95)
        ], now: now)

        XCTAssertEqual(sample?.id, "iops:42")
        XCTAssertEqual(sample?.name, "Example Power Bank")
        XCTAssertNil(sample?.model)
        XCTAssertEqual(sample?.vendorID, 1234)
        XCTAssertEqual(sample?.productID, 5678)
        XCTAssertEqual(sample?.source, .hidUPS)
        XCTAssertEqual(sample?.state, .discharging)
        XCTAssertEqual(sample?.remainingPercent, 72)
        XCTAssertEqual(sample?.voltageVolts, 20)
        XCTAssertEqual(sample?.currentAmps, -2.25)
        XCTAssertEqual(sample?.outputWatts, 45)
        XCTAssertEqual(sample?.timeToEmpty, RuntimeEstimate(seconds: 5_700, source: .system))
        XCTAssertEqual(sample?.timestamp, now)
    }

    func testUSBIdentityEnrichesCompatibleTelemetryOnly() {
        let now = Date()
        let provider = FixturePowerBankProvider(samples: [
            PowerBankSample(
                id: "iops:9",
                name: "Power Bank",
                vendorID: 111,
                productID: 222,
                state: .discharging,
                remainingPercent: 55,
                source: .hidUPS,
                timestamp: now
            )
        ])
        let identities = FixturePowerBankIdentityProvider(values: [
            USBPowerBankIdentity(
                vendorID: 111,
                productID: 222,
                name: "PB-Example",
                serialNumber: nil
            )
        ])
        let reader = PowerBankTelemetryReader(
            telemetryProviders: [provider],
            identityProvider: identities
        )
        let result = reader.read(now: now)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.name, "PB-Example")
        XCTAssertEqual(result.first?.model, "PB-Example")

        let unsupportedReader = PowerBankTelemetryReader(
            telemetryProviders: [FixturePowerBankProvider(samples: [])],
            identityProvider: identities
        )
        XCTAssertTrue(unsupportedReader.read(now: now).isEmpty)
    }

    func testPowerBankChargingStateDoesNotMislabelInputAsOutput() {
        let sample = PowerBankParser.powerSource([
            "Type": "UPS",
            "Transport Type": "USB",
            "Power Source ID": 7,
            "Name": "Bidirectional Bank",
            "Is Charging": true,
            "Power Source State": "AC Power",
            "Current Capacity": 40,
            "Max Capacity": 100,
            "Voltage": 9_000,
            "Current": 2_000
        ])
        XCTAssertEqual(sample?.state, .charging)
        XCTAssertNil(sample?.outputWatts)
        XCTAssertEqual(sample?.currentAmps, 2)
    }

    func testEmptyPowerBankPercentageIsPreservedAsRealZero() {
        let sample = PowerBankParser.powerSource([
            "Type": "UPS",
            "Power Source ID": 70,
            "Name": "Empty Bank",
            "Is Present": true,
            "Power Source State": "Battery Power",
            "Current Capacity": 0,
            "Max Capacity": 100
        ])
        XCTAssertEqual(sample?.remainingPercent, 0)
    }

    func testInternalAndUnsupportedPowerSourcesRemainInvisible() {
        let internalBattery: [String: Any] = [
            "Type": "InternalBattery",
            "Power Source ID": 1,
            "Current Capacity": 80,
            "Max Capacity": 100
        ]
        let ordinaryAdapter: [String: Any] = [
            "Type": "AC Power",
            "Power Source ID": 2,
            "Voltage": 20_000
        ]
        let unmeteredUPS: [String: Any] = [
            "Type": "UPS",
            "Power Source ID": 3,
            "Name": "No Telemetry",
            "Is Present": true,
            "Power Source State": "AC Power"
        ]
        XCTAssertNil(PowerBankParser.powerSource(internalBattery))
        XCTAssertNil(PowerBankParser.powerSource(ordinaryAdapter))
        XCTAssertNil(PowerBankParser.powerSource(unmeteredUPS))
        XCTAssertNil(PowerBankParser.preferred([]))
    }

    func testDisconnectedOfflineAndMalformedPowerBanksRemainInvisible() {
        XCTAssertNil(PowerBankParser.powerSource([
            "Type": "UPS",
            "Power Source ID": 4,
            "Is Present": false,
            "Current Capacity": 50,
            "Max Capacity": 100
        ]))
        XCTAssertNil(PowerBankParser.powerSource([
            "Type": "UPS",
            "Power Source ID": 5,
            "Power Source State": "Off Line",
            "Current Capacity": 50,
            "Max Capacity": 100
        ]))
        let malformed = PowerBankParser.powerSource([
            "Type": "UPS",
            "Power Source ID": 6,
            "Power Source State": "Battery Power",
            "Current Capacity": "fifty",
            "Max Capacity": NSNumber(value: Double.nan),
            "Voltage": NSNumber(value: Int64.max),
            "Current": NSNumber(value: Int64.min),
            "Time to Empty": -1
        ])
        XCTAssertNil(malformed)
    }

    func testStalePowerBankTelemetryIsNotVisible() {
        let now = Date(timeIntervalSince1970: 2_000)
        let stale = PowerBankSample(
            id: "stale",
            name: "Stale Bank",
            state: .discharging,
            remainingPercent: 50,
            source: .hidUPS,
            timestamp: now.addingTimeInterval(-6)
        )
        XCTAssertTrue(PowerBankParser.visible([stale], now: now).isEmpty)
        XCTAssertNil(PowerBankParser.preferred([stale], now: now))
    }

    func testMultiplePowerBanksPreferActiveDischargingSource() {
        let now = Date()
        let charging = PowerBankSample(
            id: "charging",
            name: "Charging Bank",
            state: .charging,
            remainingPercent: 80,
            source: .hidUPS,
            timestamp: now
        )
        let active = PowerBankSample(
            id: "active",
            name: "Active Bank",
            state: .discharging,
            remainingPercent: 60,
            outputWatts: 35,
            source: .hidUPS,
            timestamp: now
        )
        let weaker = PowerBankSample(
            id: "weaker",
            name: "Weaker Bank",
            state: .discharging,
            remainingPercent: 90,
            outputWatts: 15,
            source: .hidUPS,
            timestamp: now
        )
        XCTAssertEqual(PowerBankParser.preferred([charging, weaker, active], now: now)?.id, "active")
    }

    func testCalculatedPowerBankRuntimeFromObservedPercentageDrop() {
        var estimator = PowerBankRuntimeEstimator(
            minimumObservationTime: 10,
            minimumPercentDrop: 1,
            maximumObservationTime: 120
        )
        let start = Date(timeIntervalSince1970: 1_000)
        var sample = PowerBankSample(
            id: "bank",
            name: "Bank",
            state: .discharging,
            remainingPercent: 80,
            source: .hidUPS,
            timestamp: start
        )
        XCTAssertNil(estimator.estimate(for: sample))
        sample.remainingPercent = 78
        sample.timestamp = start.addingTimeInterval(20)
        let runtime = estimator.estimate(for: sample)
        XCTAssertEqual(runtime?.source, .calculated)
        XCTAssertEqual(runtime!.seconds, 780, accuracy: 0.001)

        sample.state = .charging
        XCTAssertNil(estimator.estimate(for: sample))
    }

    func testEstimatedPowerBankPercentAtMacChargeTarget() {
        let projection = PowerBankEstimator.percentAtMacTarget(
            currentPercent: 80,
            powerBankRuntime: .init(seconds: 4 * 3_600, source: .system),
            macRuntime: .init(seconds: 90 * 60, source: .system)
        )
        XCTAssertEqual(projection!, 50, accuracy: 0.001)
        XCTAssertEqual(PowerBankEstimator.percentAtMacTarget(
            currentPercent: 30,
            powerBankRuntime: .init(seconds: 60 * 60, source: .calculated),
            macRuntime: .init(seconds: 2 * 60 * 60, source: .system)
        ), 0)
        XCTAssertNil(PowerBankEstimator.percentAtMacTarget(
            currentPercent: nil,
            powerBankRuntime: nil,
            macRuntime: nil
        ))
    }
}

private struct FixturePowerBankProvider: PowerBankTelemetryProvider {
    let samples: [PowerBankSample]

    func readPowerBanks(now: Date) -> [PowerBankSample] {
        samples
    }
}

private struct FixturePowerBankIdentityProvider: PowerBankIdentityProvider {
    let values: [USBPowerBankIdentity]

    func identities() -> [USBPowerBankIdentity] {
        values
    }
}
