import Foundation

public struct PopoverDimensions: Equatable, Sendable {
    public let width: Double
    public let settingsHeight: Double

    public init(width: Double, settingsHeight: Double) {
        self.width = width
        self.settingsHeight = settingsHeight
    }
}

public struct PopoverOrigin: Equatable, Sendable {
    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public enum PopoverGeometry {
    public static func fit(visibleWidth: Double, visibleHeight: Double) -> PopoverDimensions {
        PopoverDimensions(
            width: min(370, max(280, visibleWidth - 48)),
            settingsHeight: min(640, max(360, visibleHeight - 72))
        )
    }

    public static func clampedWindowOrigin(
        originX: Double,
        originY: Double,
        windowWidth: Double,
        windowHeight: Double,
        visibleMinX: Double,
        visibleMinY: Double,
        visibleMaxX: Double,
        visibleMaxY: Double,
        margin: Double = 12
    ) -> PopoverOrigin {
        let minimumX = visibleMinX + margin
        let minimumY = visibleMinY + margin
        let maximumX = max(minimumX, visibleMaxX - margin - windowWidth)

        return PopoverOrigin(
            x: min(max(originX, minimumX), maximumX),
            // Keep AppKit's native menu-bar attachment at the top edge. Only
            // lift the popover when its lower edge would leave the screen.
            y: max(originY, minimumY)
        )
    }
}
