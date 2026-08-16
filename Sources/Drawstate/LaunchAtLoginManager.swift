import Foundation
import ServiceManagement

enum LaunchAtLoginManager {
    private static let legacyLabel = "com.kiankonradtajbakhsh.drawstate.launcher"

    private static var legacyAgentURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(legacyLabel).plist")
    }

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static var requiresApproval: Bool {
        SMAppService.mainApp.status == .requiresApproval
    }

    static func ensureCurrentConfiguration() throws {
        try migrateLegacyAgentIfNeeded()
    }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            guard SMAppService.mainApp.status != .enabled else { return }
            try SMAppService.mainApp.register()
        } else {
            guard SMAppService.mainApp.status != .notRegistered else { return }
            try SMAppService.mainApp.unregister()
        }
    }

    static func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    private static func migrateLegacyAgentIfNeeded() throws {
        guard FileManager.default.fileExists(atPath: legacyAgentURL.path) else { return }
        _ = runLaunchctl(["bootout", "gui/\(getuid())/\(legacyLabel)"])
        try FileManager.default.removeItem(at: legacyAgentURL)
        if SMAppService.mainApp.status == .notRegistered {
            try SMAppService.mainApp.register()
        }
    }

    @discardableResult
    private static func runLaunchctl(_ arguments: [String]) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus
        } catch {
            return -1
        }
    }
}
