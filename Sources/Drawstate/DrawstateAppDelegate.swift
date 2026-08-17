import AppKit
import Combine
import SwiftUI
import DrawstateCore

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
