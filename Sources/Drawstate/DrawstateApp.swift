import AppKit
import Combine
import CoreText
import SwiftUI
import DrawstateCore

private extension Notification.Name {
    static let drawstateShowWelcome = Notification.Name("com.kiankonradtajbakhsh.drawstate.showWelcome")
}

@main
struct DrawstateApp: App {
    @NSApplicationDelegateAdaptor(DrawstateAppDelegate.self) private var appDelegate

    init() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "launchAtLoginConfigured") == nil {
            try? LaunchAtLoginManager.ensureCurrentConfiguration()
            defaults.set(true, forKey: "launchAtLoginConfigured")
        } else {
            try? LaunchAtLoginManager.ensureCurrentConfiguration()
        }
    }

    var body: some Scene {
        Settings {
            DrawstateSettings()
        }
    }
}

@MainActor
final class DrawstateAppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private let monitor = PowerMonitor()
    private let popoverLayout = DrawstatePopoverLayout()
    private var statusItem: NSStatusItem?
    private var menuBarButton: NSButton?
    private let popover = NSPopover()
    private var welcomeWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()
    private var transientIdentity: String?
    private var transientStartedAt = Date()

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureStatusItem()
        NotificationCenter.default.publisher(for: .drawstateShowWelcome)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.showWelcomeWindow() }
            .store(in: &cancellables)
        monitor.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                DispatchQueue.main.async { self?.updateStatusItem() }
            }
            .store(in: &cancellables)

        if !UserDefaults.standard.bool(forKey: "hasCompletedWelcome") ||
            ProcessInfo.processInfo.arguments.contains("--show-welcome") {
            DispatchQueue.main.async { [weak self] in self?.showWelcomeWindow() }
        }
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.autosaveName = "com.kiankonradtajbakhsh.drawstate.statusItem"
        item.behavior = [.removalAllowed]
        item.isVisible = true
        statusItem = item

        guard let button = item.button else { return }
        menuBarButton = button
        button.target = self
        button.action = #selector(togglePopover(_:))
        button.imagePosition = .imageLeading
        button.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        button.imageScaling = .scaleProportionallyDown
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(
            rootView: DrawstatePanel(monitor: monitor, layout: popoverLayout)
        )
        updateStatusItem()
    }

    @objc private func togglePopover(_ sender: NSButton) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popoverLayout.update(for: sender.window?.screen ?? NSScreen.main)
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            DispatchQueue.main.async { [weak self] in
                self?.popover.contentViewController?.view.window?.makeFirstResponder(nil)
            }
        }
    }

    private func updateStatusItem() {
        guard let button = menuBarButton else { return }
        let defaults = UserDefaults.standard
        let compact = defaults.object(forKey: "compactMenuText") as? Bool ?? true
        let showIcon = defaults.object(forKey: "showMenuIcon") as? Bool ?? true
        let showPercentage = defaults.object(forKey: "showMenuPercentage") as? Bool ?? true
        let showWattage = defaults.object(forKey: "showMenuWattage") as? Bool ?? true
        let showRuntime = defaults.object(forKey: "showMenuRuntime") as? Bool ?? true
        let showDirection = defaults.object(forKey: "showPowerDirectionSign") as? Bool ?? true
        let embeddedPercentage = defaults.object(forKey: "percentageInsideBatteryIcon") as? Bool ?? true
        let hideTemporary = defaults.object(forKey: "hideTemporaryMenuStates") as? Bool ?? true
        let shouldEmbed = showIcon && showPercentage && embeddedPercentage &&
            PowerFormatting.roundedPercent(monitor.sample.batteryPercent) != nil

        var parts: [String] = []
        if showPercentage && !shouldEmbed {
            parts.append(PowerFormatting.percent(monitor.sample.batteryPercent))
        }
        if showWattage {
            parts.append(showDirection
                ? PowerFormatting.directionalWatts(
                    monitor.displayWatts,
                    receiving: monitor.sample.externalConnected,
                    compact: compact
                )
                : (compact
                    ? PowerFormatting.compactWatts(monitor.displayWatts)
                    : PowerFormatting.watts(monitor.displayWatts)))
        }
        if showRuntime, let runtimeText = runtimeMenuText(compact: compact, hideTemporary: hideTemporary) {
            parts.append(runtimeText)
        }

        if showIcon || parts.isEmpty {
            if shouldEmbed,
               let percentage = PowerFormatting.roundedPercent(monitor.sample.batteryPercent) {
                button.image = DrawstateMenuIconFactory.batteryPercentageImage(percentage)
                button.image?.isTemplate = false
            } else {
                let symbol = NSImage(
                    systemSymbolName: fallbackSymbol,
                    accessibilityDescription: "Drawstate battery"
                )
                button.image = symbol?.withSymbolConfiguration(
                    NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)
                )
                button.image?.isTemplate = true
            }
        } else {
            button.image = nil
        }
        button.title = parts.joined(separator: " ")
        button.imagePosition = button.image == nil
            ? .noImage
            : (button.title.isEmpty ? .imageOnly : .imageLeading)
        statusItem?.length = NSStatusItem.variableLength
        button.toolTip = parts.isEmpty ? "Drawstate" : "Drawstate, \(parts.joined(separator: ", "))"
        button.setAccessibilityLabel(button.toolTip)
    }

    private var fallbackSymbol: String {
        guard let percentage = PowerFormatting.roundedPercent(monitor.sample.batteryPercent) else {
            return "exclamationmark.circle"
        }
        switch percentage {
        case 88...: return "battery.100percent"
        case 63...: return "battery.75percent"
        case 38...: return "battery.50percent"
        case 13...: return "battery.25percent"
        default: return "battery.0percent"
        }
    }

    private func runtimeMenuText(compact: Bool, hideTemporary: Bool) -> String? {
        if monitor.sample.state == .full { return "Full" }
        let temporary: String?
        switch monitor.sample.state {
        case .paused: temporary = "Paused"
        case .external where !monitor.sample.isCharging: temporary = compact ? "Plugged" : "Connected"
        case .unavailable: temporary = compact ? "No data" : "Unavailable"
        default: temporary = monitor.runtime == nil ? (compact ? "Calc…" : "Calculating…") : nil
        }
        if transientIdentity != temporary {
            transientIdentity = temporary
            transientStartedAt = Date()
        }
        if let temporary {
            return !hideTemporary || PowerFormatting.temporaryStatusIsVisible(
                since: transientStartedAt,
                now: Date()
            )
                ? temporary : nil
        }
        return compact ? PowerFormatting.compactRuntime(monitor.runtime) : PowerFormatting.runtime(monitor.runtime)
    }

    func showWelcomeWindow() {
        if let welcomeWindow {
            NSApplication.shared.activate(ignoringOtherApps: true)
            welcomeWindow.makeKeyAndOrderFront(nil)
            return
        }

        let icon = NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath)
        icon.size = NSSize(width: 144, height: 144)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 560),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Welcome to Drawstate"
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.animationBehavior = .documentWindow
        window.delegate = self
        window.contentViewController = NSHostingController(
            rootView: DrawstateWelcomeView(appIcon: icon) { [weak window] in
                UserDefaults.standard.set(true, forKey: "hasCompletedWelcome")
                window?.close()
            }
        )
        window.center()
        welcomeWindow = window
        NSApplication.shared.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, window === welcomeWindow else { return }
        UserDefaults.standard.set(true, forKey: "hasCompletedWelcome")
        welcomeWindow = nil
    }
}

@MainActor
final class DrawstatePopoverLayout: ObservableObject {
    @Published private(set) var width: CGFloat = 370
    @Published private(set) var settingsHeight: CGFloat = 640

    func update(for screen: NSScreen?) {
        guard let visibleFrame = screen?.visibleFrame else { return }
        let dimensions = PopoverGeometry.fit(
            visibleWidth: Double(visibleFrame.width),
            visibleHeight: Double(visibleFrame.height)
        )
        width = CGFloat(dimensions.width)
        settingsHeight = CGFloat(dimensions.settingsHeight)
    }
}

@MainActor
private enum DrawstateMenuIconFactory {
    private static var cache: [String: NSImage] = [:]

    static func batteryPercentageImage(_ percentage: Int) -> NSImage {
        let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let cacheKey = "\(percentage)-\(isDark ? "dark" : "light")"
        if let cached = cache[cacheKey] { return cached }
        let foregroundColor: NSColor = isDark ? .white : .black
        let backgroundColor: NSColor = isDark ? .black : .white
        let clampedPercentage = min(100, max(0, percentage))
        let fillColor: NSColor = clampedPercentage <= 20 ? .systemRed : foregroundColor
        let filledDigitColor: NSColor = clampedPercentage <= 20 ? .white : backgroundColor
        let size = NSSize(width: 30, height: 16)
        let image = NSImage(size: size, flipped: false) { _ in
            let bodyRect = NSRect(x: 0.8, y: 2.0, width: 25.0, height: 12.0)
            let interiorRect = bodyRect.insetBy(dx: 2.25, dy: 2.25)
            let bodyPath = NSBezierPath(
                roundedRect: bodyRect,
                xRadius: 3.2,
                yRadius: 3.2
            )
            bodyPath.lineWidth = 1.5
            foregroundColor.setStroke()
            bodyPath.stroke()

            foregroundColor.withAlphaComponent(0.58).setFill()
            NSBezierPath(
                roundedRect: NSRect(x: 26.45, y: 5.15, width: 2.25, height: 5.7),
                xRadius: 1.1,
                yRadius: 1.1
            ).fill()

            let rawFillWidth = interiorRect.width * CGFloat(clampedPercentage) / 100
            let fillWidth = clampedPercentage == 0 ? 0 : max(1.25, rawFillWidth)
            let fillRect = NSRect(
                x: interiorRect.minX,
                y: interiorRect.minY,
                width: min(interiorRect.width, fillWidth),
                height: interiorRect.height
            )
            if fillWidth > 0 {
                NSGraphicsContext.saveGraphicsState()
                NSBezierPath(
                    roundedRect: interiorRect,
                    xRadius: 1.45,
                    yRadius: 1.45
                ).addClip()
                fillColor.setFill()
                fillRect.fill()
                NSGraphicsContext.restoreGraphicsState()
            }

            let fontSize: CGFloat = clampedPercentage == 100 ? 6.7 : 7.8
            let font = NSFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .semibold)
            let digitString = "\(clampedPercentage)"

            func drawDigits(color: NSColor, clippedTo clipRect: NSRect? = nil) {
                guard let context = NSGraphicsContext.current?.cgContext else { return }
                let line = CTLineCreateWithAttributedString(
                    NSAttributedString(
                        string: digitString,
                        attributes: [.font: font, .foregroundColor: color]
                    )
                )
                var ascent: CGFloat = 0
                var descent: CGFloat = 0
                var leading: CGFloat = 0
                let textWidth = CGFloat(CTLineGetTypographicBounds(
                    line,
                    &ascent,
                    &descent,
                    &leading
                ))
                let baseline = CGPoint(
                    x: bodyRect.midX - textWidth / 2,
                    y: bodyRect.midY - font.capHeight / 2
                )
                context.saveGState()
                if let clipRect { context.clip(to: clipRect) }
                context.setBlendMode(.normal)
                context.textPosition = baseline
                CTLineDraw(line, context)
                context.restoreGState()
            }

            drawDigits(color: foregroundColor)
            if fillWidth > 0 {
                drawDigits(color: filledDigitColor, clippedTo: fillRect)
            }
            return true
        }
        image.isTemplate = false
        image.accessibilityDescription = "Battery \(percentage) percent"
        cache[cacheKey] = image
        return image
    }
}
struct DrawstatePanel: View {
    @ObservedObject var monitor: PowerMonitor
    @ObservedObject var layout: DrawstatePopoverLayout
    @State private var showingSettings = false
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
    @AppStorage("experimentalChargeLimitControl") private var experimentalChargeLimitControl = false

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

            if showBatterySettingsCard {
                BatterySettingsCard(
                    monitor: monitor,
                    allowsChargeControl: experimentalChargeLimitControl
                )
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

private struct DrawstateSettings: View {
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
    @AppStorage("experimentalChargeLimitControl") private var experimentalChargeLimitControl = false

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
                Toggle("Energy mode and charge limit", isOn: $showBatterySettingsCard)
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

            Section("Experimental") {
                Toggle("Allow charge-limit changes", isOn: $experimentalChargeLimitControl)
                Text("This optional control uses an undocumented macOS Smart Charge service. It may stop working after a macOS update. Drawstate always verifies a requested change and remains usable if macOS rejects it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("About") {
                LabeledContent("Creator", value: "Kian Konrad Tajbakhsh")
                LabeledContent("License", value: "MIT License")
                Button("Show Welcome Window…") {
                    NotificationCenter.default.post(name: .drawstateShowWelcome, object: nil)
                }
                Text("Drawstate is open-source software.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
