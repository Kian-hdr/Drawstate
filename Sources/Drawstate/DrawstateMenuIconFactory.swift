import AppKit
import CoreText

@MainActor
enum DrawstateMenuIconFactory {
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
            let bodyPath = NSBezierPath(roundedRect: bodyRect, xRadius: 3.2, yRadius: 3.2)
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
