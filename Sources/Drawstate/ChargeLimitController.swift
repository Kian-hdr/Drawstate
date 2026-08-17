#if !APP_STORE
import Foundation
import DrawstateCore

enum ChargeLimitController {
    static var isAvailable: Bool {
        bridgeURL != nil && FileManager.default.isExecutableFile(atPath: "/usr/bin/swift")
    }

    static func setLimit(_ limit: Int) async throws {
        try await Task.detached(priority: .userInitiated) {
            try setLimitSynchronously(limit)
        }.value
    }

    private static func setLimitSynchronously(_ limit: Int) throws {
        guard SystemBatterySettingsParser.allowedChargeLimits.contains(limit) else {
            throw ChargeLimitControlError.invalidLimit
        }
        let output = try runHelper(arguments: ["set", String(limit)])
        guard output.trimmingCharacters(in: .whitespacesAndNewlines) == "verified=\(limit)" else {
            throw ChargeLimitControlError.verificationFailed
        }
    }

    private static var bridgeURL: URL? {
        let bundled = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Resources/ChargeLimitBridge.swift")
        if FileManager.default.fileExists(atPath: bundled.path) { return bundled }
        return nil
    }

    private static func runHelper(arguments: [String]) throws -> String {
        guard let bridgeURL else { throw ChargeLimitControlError.unavailable }
        let process = Process()
        let standardOutput = Pipe()
        let standardError = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
        process.arguments = [bridgeURL.path] + arguments
        process.standardOutput = standardOutput
        process.standardError = standardError
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw ChargeLimitControlError.systemError(error.localizedDescription)
        }

        let output = String(
            data: standardOutput.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        ) ?? ""
        guard process.terminationStatus == 0 else {
            let errorText = String(
                data: standardError.fileHandleForReading.readDataToEndOfFile(),
                encoding: .utf8
            )?.trimmingCharacters(in: .whitespacesAndNewlines)
            throw ChargeLimitControlError.systemError(errorText)
        }
        return output
    }
}

private enum ChargeLimitControlError: LocalizedError {
    case invalidLimit
    case unavailable
    case systemError(String?)
    case verificationFailed

    var errorDescription: String? {
        switch self {
        case .invalidLimit:
            return "Choose a charge limit from 80% to 100% in 5% steps."
        case .unavailable:
            return "Charge-limit control is unavailable in this Drawstate installation."
        case .systemError(let message):
            return message?.isEmpty == false ? message : "macOS rejected the charge-limit change."
        case .verificationFailed:
            return "macOS did not report the requested limit after the change."
        }
    }
}
#endif
