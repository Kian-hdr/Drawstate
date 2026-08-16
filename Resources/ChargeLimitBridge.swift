import Darwin
import Foundation
import ObjectiveC.runtime

enum BridgeFailure: LocalizedError {
    case invalidArguments
    case unavailable
    case rejected(String?)
    case verificationFailed(expected: Int, actual: Int)

    var errorDescription: String? {
        switch self {
        case .invalidArguments:
            return "Expected a charge limit of 80, 85, 90, 95, or 100."
        case .unavailable:
            return "Apple Smart Charge service is unavailable."
        case .rejected(let message):
            return message ?? "Apple Smart Charge service rejected the change."
        case .verificationFailed(let expected, let actual):
            return "Requested \(expected)% but macOS reported \(actual)%."
        }
    }
}

func writeError(_ message: String) {
    FileHandle.standardError.write(Data((message + "\n").utf8))
}

func setChargeLimit(_ limit: Int) throws {
    guard [80, 85, 90, 95, 100].contains(limit) else {
        throw BridgeFailure.invalidArguments
    }
    guard dlopen("/System/Library/PrivateFrameworks/ActionKit.framework/ActionKit", RTLD_NOW) != nil,
          let helper = NSClassFromString("WFSmartChargeClientHelper"),
          let message = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "objc_msgSend") else {
        throw BridgeFailure.unavailable
    }

    typealias SetFunction = @convention(c) (
        AnyClass, Selector, Int, UnsafeMutablePointer<Unmanaged<AnyObject>?>?
    ) -> Bool
    typealias GetFunction = @convention(c) (
        AnyClass, Selector, UnsafeMutablePointer<Unmanaged<AnyObject>?>?
    ) -> Int

    let set = unsafeBitCast(message, to: SetFunction.self)
    var setError: Unmanaged<AnyObject>?
    guard set(helper, NSSelectorFromString("setMCLLimit:error:"), limit, &setError) else {
        let message = (setError?.takeUnretainedValue() as? NSError)?.localizedDescription
        throw BridgeFailure.rejected(message)
    }

    let get = unsafeBitCast(message, to: GetFunction.self)
    var getError: Unmanaged<AnyObject>?
    let actual = get(helper, NSSelectorFromString("getMCLLimitWithError:"), &getError)
    guard getError == nil, actual == limit else {
        throw BridgeFailure.verificationFailed(expected: limit, actual: actual)
    }
}

do {
    let arguments = Array(CommandLine.arguments.dropFirst())
    guard arguments.count == 2, arguments[0] == "set", let limit = Int(arguments[1]) else {
        throw BridgeFailure.invalidArguments
    }
    try setChargeLimit(limit)
    print("verified=\(limit)")
} catch {
    writeError(error.localizedDescription)
    exit(1)
}
