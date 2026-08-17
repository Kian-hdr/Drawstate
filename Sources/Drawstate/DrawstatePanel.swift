import AppKit
import SwiftUI
import DrawstateCore

struct DrawstatePanel: View {
    @ObservedObject var monitor: PowerMonitor
    @ObservedObject var layout: DrawstatePopoverLayout
    @State private var showingSettings = false
    @State private var showingDirectInfo = false
    @AppStorage("showPowerDirectionSign") private var showPowerDirectionSign = true
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

    var body: some View {
        Group {
            if showingSettings {
                DrawstateSettings(
                    isEmbedded: true,
                    embeddedWidth: layout.width,
                    embeddedHeight: layout.settingsHeight
                ) {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        showingSettings = false
                    }
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            } else if showingDirectInfo {
#if APP_STORE
                DrawstateDirectInfoView(
                    width: layout.width,
                    height: layout.settingsHeight
                ) {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        showingDirectInfo = false
                    }
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
#else
                EmptyView()
#endif
            } else {
                dashboard
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
    }

    private var dashboard: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            if showFlowDiagram {
                PowerFlowView(sample: monitor.sample)
            }

            LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 10) {
                if showMacDrawCard {
                    MetricCard(title: "Mac draw", value: PowerFormatting.watts(monitor.sample.systemLoadWatts), icon: "desktopcomputer")
                }
                if showWallDrawCard {
                    MetricCard(title: "Est. wall draw", value: PowerFormatting.watts(monitor.sample.wallInputWatts), icon: "powerplug.fill")
                }
                if showPowerPlugCard {
                    MetricCard(title: "From power plug", value: PowerFormatting.watts(monitor.sample.adapterContributionWatts), icon: "arrow.right.circle")
                }
                if showBatteryFlowCard {
                    MetricCard(title: batteryFlowTitle, value: PowerFormatting.watts(monitor.sample.batteryFlowWatts), icon: batteryFlowIcon)
                }
                if showRuntimeCard {
                    MetricCard(title: monitor.primaryRuntimeLabel, value: monitor.primaryRuntimeValue, subtitle: monitor.runtimeSource, icon: "clock")
                }
                if showBatteryCard {
                    MetricCard(title: "Battery", value: percentText, subtitle: healthText, icon: "battery.75percent")
                }
            }

            if let powerBank = monitor.primaryPowerBank {
                PowerBankCard(
                    sample: powerBank,
                    compatibleSourceCount: monitor.powerBanks.count
                )
            }

            if showBatterySettingsCard {
#if APP_STORE
                BatterySettingsCard(monitor: monitor) {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        showingDirectInfo = true
                    }
                }
#else
                BatterySettingsCard(
                    monitor: monitor,
                    allowsChargeControl: experimentalChargeLimitControl
                )
#endif
            }

            if showElectricalDetails {
                Divider()
                details
            }
            Divider()

            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        showingSettings = true
                    }
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
                    .buttonStyle(.plain)
                Spacer()
                Button("Quit Drawstate") { NSApplication.shared.terminate(nil) }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }
            .font(.callout)
        }
        .padding(16)
        .frame(width: layout.width)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("Drawstate").font(.title2.bold())
                Text(monitor.sample.state.rawValue).foregroundStyle(statusColor)
            }
            Spacer()
            Text(showPowerDirectionSign
                ? PowerFormatting.directionalWatts(
                    monitor.displayWatts,
                    receiving: monitor.sample.externalConnected,
                    compact: false
                )
                : PowerFormatting.watts(monitor.displayWatts))
                .font(.system(size: 25, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
    }

    private var details: some View {
        Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
            detailRow("Voltage", monitor.sample.voltageVolts.map { String(format: "%.2f V", $0) } ?? "—")
            detailRow("Battery current", monitor.sample.currentAmps.map { String(format: "%+.2f A", $0) } ?? "—")
            detailRow("Adapter rating", PowerFormatting.watts(monitor.sample.adapterRatedWatts))
            detailRow("Cycle count", monitor.sample.cycleCount.map(String.init) ?? "—")
            detailRow("Updated", monitor.sample.timestamp.formatted(date: .omitted, time: .standard))
        }
        .font(.caption)
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        GridRow {
            Text(title).foregroundStyle(.secondary)
            Text(value).monospacedDigit()
        }
    }

    private var percentText: String {
        PowerFormatting.percent(monitor.sample.batteryPercent)
    }

    private var healthText: String? {
        monitor.sample.healthPercent.map { String(format: "%.0f%% health", $0) }
    }

    private var batteryFlowTitle: String {
        guard let flow = monitor.sample.batteryFlowWatts else { return "Battery flow" }
        return flow >= 0 ? "Into battery" : "From battery"
    }

    private var batteryFlowIcon: String {
        (monitor.sample.batteryFlowWatts ?? 0) >= 0 ? "arrow.down.to.line" : "arrow.up.to.line"
    }

    private var statusColor: Color {
        switch monitor.sample.state {
        case .charging: return .green
        case .battery: return .orange
        case .full: return .mint
        case .paused, .external: return .blue
        case .unavailable: return .red
        }
    }
}

private struct PowerBankCard: View {
    let sample: PowerBankSample
    let compatibleSourceCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline) {
                Label("Power Bank", systemImage: "battery.75percent")
                    .font(.headline)
                Spacer()
                if let percent = PowerFormatting.roundedPercent(sample.remainingPercent) {
                    Text("\(percent)%")
                        .font(.headline.monospacedDigit())
                }
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(sample.name).fontWeight(.semibold)
                    if let model = sample.model, model != sample.name {
                        Text(model).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text(sample.state.rawValue)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(stateColor)
            }

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 5) {
                if let watts = sample.outputWatts {
                    row("Output", PowerFormatting.watts(watts))
                }
                if let voltage = sample.voltageVolts {
                    row("Voltage", String(format: "%.2f V", voltage))
                }
                if let current = sample.currentAmps {
                    row("Current", String(format: "%+.2f A", current))
                }
                if let runtime = sample.timeToEmpty {
                    row(
                        runtime.source == .calculated ? "Est. until empty" : "Until empty",
                        PowerFormatting.runtime(runtime)
                    )
                }
                if let percent = PowerFormatting.roundedPercent(sample.estimatedPercentAtMacTarget) {
                    row("Est. at Mac target", "\(percent)%")
                }
            }
            .font(.caption)

            if compatibleSourceCount > 1 {
                Text("Showing the active source from \(compatibleSourceCount) compatible power sources.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 12))
    }

    private func row(_ title: String, _ value: String) -> some View {
        GridRow {
            Text(title).foregroundStyle(.secondary)
            Text(value).monospacedDigit()
        }
    }

    private var stateColor: Color {
        switch sample.state {
        case .charging: return .green
        case .discharging: return .orange
        case .full: return .mint
        case .idle: return .blue
        }
    }
}

#if APP_STORE
private struct BatterySettingsCard: View {
    @ObservedObject var monitor: PowerMonitor
    let showDirectInfo: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            Label("Battery Settings", systemImage: "slider.horizontal.3")
                .font(.headline)

            HStack {
                Label("Energy Mode", systemImage: energyModeIcon)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(monitor.batterySettings.energyMode?.rawValue ?? "—")
                    .fontWeight(.medium)
            }

            Button("Open Battery Settings") {
                DrawstateLinks.openBatterySettings()
            }

            Divider()

            Button(action: showDirectInfo) {
                HStack(spacing: 9) {
                    Image(systemName: "bolt.shield")
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Charge-limit controls")
                        Text("Available in Drawstate Direct")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 12))
    }

    private var energyModeIcon: String {
        monitor.batterySettings.energyMode == .lowPower
            ? "leaf.fill"
            : "gauge.with.dots.needle.50percent"
    }
}

private struct DrawstateDirectInfoView: View {
    let width: CGFloat
    let height: CGFloat
    let onDone: () -> Void
    @State private var isHoveringHomebrew = false
    @State private var copiedHomebrewCommand = false

    private let homebrewCommand = "brew install --cask kian-hdr/tap/drawstate"

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Text("Drawstate Direct")
                    .font(.headline)
                HStack {
                    Button(action: onDone) {
                        Label("Overview", systemImage: "chevron.left")
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 44)
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Label("Charge-limit controls", systemImage: "bolt.shield")
                        .font(.title3.bold())
                    Text("Drawstate Direct includes optional experimental controls for changing the Mac charge limit. The Mac App Store edition remains sandboxed and only opens Apple's Battery Settings.")
                        .foregroundStyle(.secondary)

                    installationRow(
                        title: "GitHub Releases",
                        detail: "Download the signed Drawstate Direct release from the official repository.",
                        icon: "shippingbox"
                    )
                    Button(action: copyHomebrewCommand) {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "terminal")
                                .frame(width: 20)
                                .foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Homebrew").fontWeight(.semibold)
                                    Spacer()
                                    Label(
                                        copiedHomebrewCommand ? "Copied" : "Copy",
                                        systemImage: copiedHomebrewCommand ? "checkmark" : "doc.on.doc"
                                    )
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(copiedHomebrewCommand ? .green : .secondary)
                                }
                                Text(homebrewCommand)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                                Text("Click to copy, then paste it into Terminal.")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            isHoveringHomebrew
                                ? Color.accentColor.opacity(0.12)
                                : Color.secondary.opacity(0.08),
                            in: RoundedRectangle(cornerRadius: 12)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    isHoveringHomebrew ? Color.accentColor.opacity(0.45) : .clear,
                                    lineWidth: 1
                                )
                        }
                        .contentShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .onHover { isHoveringHomebrew = $0 }
                    .help("Copy the Homebrew installation command")

                    Button("Open installation guide…") {
                        NSWorkspace.shared.open(DrawstateLinks.directInstallationURL)
                    }

                    Text("This opens documentation in your browser. Drawstate will not download software, run Homebrew, or replace this app.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(16)
            }
        }
        .frame(width: width, height: height)
    }

    private func installationRow(title: String, detail: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).fontWeight(.semibold)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 12))
    }

    private func copyHomebrewCommand() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(homebrewCommand, forType: .string)
        copiedHomebrewCommand = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            copiedHomebrewCommand = false
        }
    }
}
#else
private struct BatterySettingsCard: View {
    @ObservedObject var monitor: PowerMonitor
    let allowsChargeControl: Bool
    @State private var selectedLimit = 80.0
    @State private var isApplyingLimit = false
    @State private var controlError: String?
    @State private var showingControlError = false

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                Label("Battery Settings", systemImage: "slider.horizontal.3")
                    .font(.headline)
                Spacer()
                Button {
                    monitor.refreshBatterySettings()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .help("Refresh battery settings")
            }

            HStack {
                Label("Energy Mode", systemImage: energyModeIcon)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(monitor.batterySettings.energyMode?.rawValue ?? "—")
                    .fontWeight(.medium)
            }

            HStack {
                Text("Charge Limit")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(limitText)
                    .fontWeight(.semibold)
                    .monospacedDigit()
            }
            if ChargeLimitController.isAvailable && allowsChargeControl {
                Slider(
                    value: $selectedLimit,
                    in: 80...100,
                    step: 5
                ) { editing in
                    if !editing { applySelectedLimit() }
                }
                .allowsHitTesting(!isApplyingLimit)
                .accessibilityLabel("Charge limit")
                .accessibilityValue("\(Int(selectedLimit)) percent")
                HStack {
                    ForEach(SystemBatterySettingsParser.allowedChargeLimits, id: \.self) { value in
                        Text("\(value)%")
                            .font(.system(size: 9, weight: value == Int(selectedLimit) ? .semibold : .regular))
                            .foregroundStyle(value == Int(selectedLimit) ? .primary : .tertiary)
                        if value != 100 { Spacer() }
                    }
                }
            } else {
                ChargeLimitScale(limit: monitor.batterySettings.chargeLimitPercent)
            }

        }
        .padding(12)
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 12))
        .onAppear { synchronizeSelectedLimit() }
        .onChange(of: monitor.batterySettings.chargeLimitPercent) { _, _ in
            if !isApplyingLimit { synchronizeSelectedLimit() }
        }
        .alert("Charge Limit Was Not Changed", isPresented: $showingControlError) {
            Button("Open Battery Settings") { openBatterySettings() }
            Button("OK", role: .cancel) {}
        } message: {
            Text(controlError ?? "macOS rejected the change.")
        }
    }

    private var limitText: String {
        monitor.batterySettings.chargeLimitPercent.map { "\($0)%" } ?? "—"
    }

    private var energyModeIcon: String {
        switch monitor.batterySettings.energyMode {
        case .lowPower: return "leaf.fill"
        case .highPower: return "gauge.with.dots.needle.100percent"
        default: return "gauge.with.dots.needle.50percent"
        }
    }

    private func synchronizeSelectedLimit() {
        if let limit = monitor.batterySettings.chargeLimitPercent {
            selectedLimit = Double(limit)
        }
    }

    private func applySelectedLimit() {
        guard !isApplyingLimit else { return }
        let requestedLimit = Int(selectedLimit.rounded())
        isApplyingLimit = true
        Task { @MainActor in
            do {
                try await ChargeLimitController.setLimit(requestedLimit)
                await monitor.refreshBatterySettingsNow()
            } catch {
                selectedLimit = Double(monitor.batterySettings.chargeLimitPercent ?? 80)
                controlError = error.localizedDescription
                showingControlError = true
            }
            isApplyingLimit = false
        }
    }

    private func openBatterySettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.Battery-Settings.extension"
        ) else { return }
        NSWorkspace.shared.open(url)
    }
}
#endif

private struct ChargeLimitScale: View {
    let limit: Int?

    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { proxy in
                let progress = CGFloat((limit ?? 80) - 80) / 20
                ZStack(alignment: .leading) {
                    Capsule().fill(.quaternary).frame(height: 5)
                    Capsule().fill(.tint).frame(width: max(5, proxy.size.width * progress), height: 5)
                    Circle()
                        .fill(limit == nil ? Color.secondary : Color.accentColor)
                        .overlay(Circle().stroke(.background, lineWidth: 2))
                        .frame(width: 14, height: 14)
                        .offset(x: max(0, min(proxy.size.width - 14, proxy.size.width * progress - 7)))
                }
                .frame(height: 14)
            }
            .frame(height: 14)

            HStack {
                ForEach([80, 85, 90, 95, 100], id: \.self) { value in
                    Text("\(value)%")
                        .font(.system(size: 9, weight: value == limit ? .semibold : .regular))
                        .foregroundStyle(value == limit ? .primary : .tertiary)
                    if value != 100 { Spacer() }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Charge limit")
        .accessibilityValue(limit.map { "\($0) percent" } ?? "Unavailable")
    }
}

private struct PowerFlowView: View {
    let sample: PowerSample

    var body: some View {
        HStack(spacing: 8) {
            flowNode("Adapter", icon: "powerplug.fill", active: sample.externalConnected)
            Image(systemName: "arrow.right")
                .foregroundStyle(sample.externalConnected ? Color.green : Color.secondary.opacity(0.35))
            flowNode("Mac", icon: "laptopcomputer", active: true)
            Image(systemName: batteryArrow).foregroundStyle(.secondary)
            flowNode("Battery", icon: "battery.75percent", active: sample.batteryPercent != nil)
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 12))
    }

    private var batteryArrow: String {
        guard let flow = sample.batteryFlowWatts else { return "arrow.left.arrow.right" }
        return flow >= 0 ? "arrow.right" : "arrow.left"
    }

    private func flowNode(_ title: String, icon: String, active: Bool) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.title3)
            Text(title).font(.caption2)
        }
        .foregroundStyle(active ? .primary : .tertiary)
        .frame(maxWidth: .infinity)
    }
}

private struct MetricCard: View {
    let title: String
    let value: String
    var subtitle: String? = nil
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Image(systemName: icon)
                Text(title)
                Spacer(minLength: 0)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            Text(value).font(.headline).monospacedDigit()
            if let subtitle {
                Text(subtitle).font(.caption2).foregroundStyle(.tertiary).lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 54, alignment: .topLeading)
        .padding(10)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
    }
}

private enum DrawstateLinks {
    static let directInstallationURL = URL(
        string: "https://github.com/Kian-hdr/Drawstate#install"
    )!

    static func openBatterySettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.Battery-Settings.extension"
        ) else { return }
        NSWorkspace.shared.open(url)
    }
}
