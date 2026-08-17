import SwiftUI

struct DrawstateSettings: View {
    var isEmbedded = false
    var embeddedWidth: CGFloat = 370
    var embeddedHeight: CGFloat = 640
    var onDone: (() -> Void)?

    @AppStorage("showMenuIcon") private var showMenuIcon = true
    @AppStorage("showMenuPercentage") private var showMenuPercentage = true
    @AppStorage("showMenuWattage") private var showMenuWattage = true
    @AppStorage("showMenuRuntime") private var showMenuRuntime = true
    @AppStorage("showPowerDirectionSign") private var showPowerDirectionSign = true
    @AppStorage("percentageInsideBatteryIcon") private var percentageInsideBatteryIcon = true
    @AppStorage("compactMenuText") private var compactMenuText = true
    @AppStorage("hideTemporaryMenuStates") private var hideTemporaryMenuStates = true
    @AppStorage("smoothReadings") private var smoothReadings = true

    @AppStorage("showFlowDiagram") private var showFlowDiagram = true
    @AppStorage("showMacDrawCard") private var showMacDrawCard = true
    @AppStorage("showWallDrawCard") private var showWallDrawCard = true
    @AppStorage("showPowerPlugCard") private var showPowerPlugCard = true
    @AppStorage("showBatteryFlowCard") private var showBatteryFlowCard = true
    @AppStorage("showRuntimeCard") private var showRuntimeCard = true
    @AppStorage("showBatteryCard") private var showBatteryCard = true
    @AppStorage("showElectricalDetails") private var showElectricalDetails = true
    @AppStorage("showBatterySettingsCard") private var showBatterySettingsCard = true
#if !APP_STORE
    @AppStorage("experimentalChargeLimitControl") private var experimentalChargeLimitControl = false
#endif

    @State private var launchAtLogin = LaunchAtLoginManager.isEnabled
    @State private var startupError: String?

    init(
        isEmbedded: Bool = false,
        embeddedWidth: CGFloat = 370,
        embeddedHeight: CGFloat = 640,
        onDone: (() -> Void)? = nil
    ) {
        self.isEmbedded = isEmbedded
        self.embeddedWidth = embeddedWidth
        self.embeddedHeight = embeddedHeight
        self.onDone = onDone
    }

    var body: some View {
        if isEmbedded {
            VStack(spacing: 0) {
                ZStack {
                    Text("Settings")
                        .font(.headline)
                    HStack {
                        Button {
                            onDone?()
                        } label: {
                            Label("Overview", systemImage: "chevron.left")
                        }
                        .buttonStyle(.plain)
                        Spacer()
                    }
                }
                .padding(.horizontal, 16)
                .frame(height: 44)
                Divider()
                settingsForm
            }
            .frame(width: embeddedWidth, height: embeddedHeight)
        } else {
            settingsForm
                .frame(width: 470, height: 620)
        }
    }

    private var settingsForm: some View {
        Form {
            Section("Menu Bar") {
                Toggle("Battery icon", isOn: $showMenuIcon)
                Toggle("Battery percentage", isOn: $showMenuPercentage)
                Toggle("Live wattage", isOn: $showMenuWattage)
                Toggle("Time remaining", isOn: $showMenuRuntime)
                Toggle("Hide temporary status text after 4 seconds", isOn: $hideTemporaryMenuStates)
                Toggle("Smooth changing values", isOn: $smoothReadings)
                Text("If all menu elements are off, a minimal status icon remains so Drawstate can still be opened.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Hold Command and drag Drawstate to place it anywhere among your menu-bar items.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Appearance") {
                Picker("Battery icon style", selection: $percentageInsideBatteryIcon) {
                    Text("Percentage Inside").tag(true)
                    Text("Original").tag(false)
                }
                .pickerStyle(.segmented)
                .disabled(!showMenuIcon || !showMenuPercentage)
                Toggle("Compact menu text", isOn: $compactMenuText)
                Toggle("Power direction sign (+/−)", isOn: $showPowerDirectionSign)
                Text("The percentage-inside style replaces the separate percentage text when both the battery icon and percentage are enabled.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Details Panel") {
#if APP_STORE
                Toggle("Energy mode and Drawstate Direct info", isOn: $showBatterySettingsCard)
#else
                Toggle("Energy mode and charge limit", isOn: $showBatterySettingsCard)
#endif
                Toggle("Power-flow diagram", isOn: $showFlowDiagram)
                Toggle("Mac draw", isOn: $showMacDrawCard)
                Toggle("Estimated wall draw", isOn: $showWallDrawCard)
                Toggle("Power-plug contribution", isOn: $showPowerPlugCard)
                Toggle("Battery charge or supply", isOn: $showBatteryFlowCard)
                Toggle("Runtime estimate", isOn: $showRuntimeCard)
                Toggle("Battery percentage and health", isOn: $showBatteryCard)
                Toggle("Voltage, current, adapter and cycles", isOn: $showElectricalDetails)
            }

            Section("Startup & Privacy") {
                Toggle("Start automatically at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        do {
                            try LaunchAtLoginManager.setEnabled(enabled)
                            startupError = nil
                        } catch {
                            startupError = error.localizedDescription
                            launchAtLogin = LaunchAtLoginManager.isEnabled
                        }
                    }
                if let startupError {
                    Text(startupError).font(.caption).foregroundStyle(.red)
                }
                if LaunchAtLoginManager.requiresApproval {
                    Button("Open Login Items Settings…") {
                        LaunchAtLoginManager.openSystemSettings()
                    }
                }
                Text("Drawstate reads local power telemetry only. It does not use administrator access, networking, analytics, or powermetrics.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

#if !APP_STORE
            Section("Drawstate Direct") {
                Toggle("Allow charge-limit changes", isOn: $experimentalChargeLimitControl)
                Text("This optional control uses an undocumented macOS Smart Charge service. It may stop working after a macOS update. Drawstate always verifies a requested change and remains usable if macOS rejects it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
#endif

            Section("About") {
                LabeledContent("Edition", value: editionName)
                LabeledContent("Creator", value: DrawstateCredits.creator)
                LabeledContent("License", value: "MIT License")
                Button("Show Welcome Window…") {
                    NotificationCenter.default.post(name: .drawstateShowWelcome, object: nil)
                }
                Text("Drawstate is open-source software.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Acknowledgments") {
                Text(DrawstateCredits.acknowledgment)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private var editionName: String {
#if APP_STORE
        "Mac App Store"
#else
        "Drawstate Direct"
#endif
    }
}
