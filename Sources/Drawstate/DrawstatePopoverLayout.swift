import AppKit
import Combine
import DrawstateCore

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
