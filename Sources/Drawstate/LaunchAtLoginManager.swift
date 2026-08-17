import Foundation
import ServiceManagement

enum LaunchAtLoginManager {
#if !APP_STORE
    private static let legacyLabel = "com.kiankonradtajbakhsh.drawstate.launcher"

    private static var legacyAgentURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(legacyLabel).plist")
    }
#endif

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static var requiresApproval: Bool {
        SMAppService.mainApp.status == .requiresApproval
    }

    static func ensureCurrentConfiguration() throws {
#if !APP_STORE
        try migrateLegacyAgentIfNeeded()
#endif
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

#if !APP_STORE
    private static func migrateLegacyAgentIfNeeded() throws {
        guard FileManager.default.fileExists(atPath: legacyAgentURL.path) else { return }
        if SMAppService.mainApp.status == .notRegistered {
            try SMAppService.mainApp.register()
        }
        _ = runLaunchctl(["bootout", "gui/\(getuid())/\(legacyLabel)"])
        try FileManager.default.removeItem(at: legacyAgentURL)
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
#endif
}
