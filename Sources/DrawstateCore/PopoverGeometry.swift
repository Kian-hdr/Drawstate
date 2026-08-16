import Foundation

public struct PopoverDimensions: Equatable, Sendable {
    public let width: Double
    public let settingsHeight: Double

    public init(width: Double, settingsHeight: Double) {
        self.width = width
        self.settingsHeight = settingsHeight
    }
}

public enum PopoverGeometry {
    public static func fit(visibleWidth: Double, visibleHeight: Double) -> PopoverDimensions {
        PopoverDimensions(
            width: min(370, max(280, visibleWidth - 48)),
            settingsHeight: min(640, max(360, visibleHeight - 72))
        )
    }
}
