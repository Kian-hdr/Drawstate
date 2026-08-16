#!/usr/bin/swift

import AppKit
import Foundation

private let projectURL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
private let resourcesURL = projectURL.appendingPathComponent("Resources")
private let appearancesURL = resourcesURL.appendingPathComponent("AppIconAppearances")
private let iconsetURL = resourcesURL.appendingPathComponent("AppIcon.iconset")

private enum Appearance: Equatable {
    case light
    case dark

    var filename: String {
        switch self {
        case .light: return "AppIcon-Light-1024.png"
        case .dark: return "AppIcon-Dark-1024.png"
        }
    }
}

private extension NSColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xff) / 255,
            green: CGFloat((hex >> 8) & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255,
            alpha: alpha
        )
    }

    static func mix(_ first: NSColor, _ second: NSColor, progress: CGFloat) -> NSColor {
        let a = first.usingColorSpace(.deviceRGB)!
        let b = second.usingColorSpace(.deviceRGB)!
        return NSColor(
            red: a.redComponent + (b.redComponent - a.redComponent) * progress,
            green: a.greenComponent + (b.greenComponent - a.greenComponent) * progress,
            blue: a.blueComponent + (b.blueComponent - a.blueComponent) * progress,
            alpha: a.alphaComponent + (b.alphaComponent - a.alphaComponent) * progress
        )
    }
}

private func roundedRect(_ rect: NSRect, radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

private func fill(_ path: NSBezierPath, gradient: NSGradient, angle: CGFloat) {
    NSGraphicsContext.saveGraphicsState()
    path.addClip()
    gradient.draw(in: path.bounds, angle: angle)
    NSGraphicsContext.restoreGraphicsState()
}

private func drawIcon(
    _ appearance: Appearance,
    size: Int = 1024,
    includeBackground: Bool = true
) throws -> Data {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else { throw CocoaError(.fileWriteUnknown) }

    bitmap.size = NSSize(width: size, height: size)
    guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw CocoaError(.fileWriteUnknown)
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    NSColor.clear.setFill()
    NSRect(x: 0, y: 0, width: size, height: size).fill()

    let scale = CGFloat(size) / 1024
    context.cgContext.scaleBy(x: scale, y: scale)
    context.cgContext.setShouldAntialias(true)
    context.imageInterpolation = .high

    let enclosure = roundedRect(NSRect(x: 32, y: 32, width: 960, height: 960), radius: 218)
    let background: NSGradient
    let enclosureStroke: NSColor
    let panelFill: NSColor
    let panelStroke: NSColor
    let cellHighlight: NSColor

    switch appearance {
    case .light:
        background = NSGradient(colors: [
            NSColor(hex: 0xf8fbff),
            NSColor(hex: 0xe7f1fb),
            NSColor(hex: 0xd6e6f7)
        ])!
        enclosureStroke = NSColor(hex: 0xffffff, alpha: 0.9)
        panelFill = NSColor(hex: 0x10233a, alpha: 0.88)
        panelStroke = NSColor(hex: 0xffffff, alpha: 0.78)
        cellHighlight = NSColor(hex: 0xffffff, alpha: 0.72)
    case .dark:
        background = NSGradient(colors: [
            NSColor(hex: 0x17263a),
            NSColor(hex: 0x0b1626),
            NSColor(hex: 0x050b14)
        ])!
        enclosureStroke = NSColor(hex: 0x5f7898, alpha: 0.55)
        panelFill = NSColor(hex: 0x06101d, alpha: 0.92)
        panelStroke = NSColor(hex: 0x7cecff, alpha: 0.72)
        cellHighlight = NSColor(hex: 0xffffff, alpha: 0.82)
    }

    if includeBackground {
        fill(enclosure, gradient: background, angle: -58)
        enclosure.lineWidth = 7
        enclosureStroke.setStroke()
        enclosure.stroke()

        let insetHighlight = roundedRect(NSRect(x: 47, y: 47, width: 930, height: 930), radius: 204)
        insetHighlight.lineWidth = 2
        NSColor.white.withAlphaComponent(appearance == .light ? 0.42 : 0.12).setStroke()
        insetHighlight.stroke()
    }

    let cyan = NSColor(hex: appearance == .light ? 0x00a9ec : 0x00c8ff)
    let aqua = NSColor(hex: appearance == .light ? 0x20d9d0 : 0x35f0dc)
    let green = NSColor(hex: appearance == .light ? 0x38d86f : 0x52ef88)

    let arcCenter = NSPoint(x: 486, y: 548)
    let radius: CGFloat = 276
    let start: CGFloat = -22
    let end: CGFloat = 222
    let segmentCount = 18
    for index in 0..<segmentCount {
        let progress0 = CGFloat(index) / CGFloat(segmentCount)
        let progress1 = CGFloat(index + 1) / CGFloat(segmentCount)
        let segment = NSBezierPath()
        segment.appendArc(
            withCenter: arcCenter,
            radius: radius,
            startAngle: start + (end - start) * progress0,
            endAngle: start + (end - start) * progress1 + 0.8
        )
        segment.lineWidth = 82
        segment.lineCapStyle = .round
        let midpoint = (progress0 + progress1) / 2
        let color = midpoint < 0.55
            ? NSColor.mix(cyan, aqua, progress: midpoint / 0.55)
            : NSColor.mix(aqua, green, progress: (midpoint - 0.55) / 0.45)
        color.setStroke()
        segment.stroke()
    }

    let arcHighlight = NSBezierPath()
    arcHighlight.appendArc(withCenter: arcCenter, radius: 259, startAngle: 8, endAngle: 202)
    arcHighlight.lineWidth = 8
    arcHighlight.lineCapStyle = .round
    NSColor.white.withAlphaComponent(appearance == .light ? 0.55 : 0.7).setStroke()
    arcHighlight.stroke()

    let batteryBody = roundedRect(NSRect(x: 694, y: 250, width: 190, height: 286), radius: 42)
    panelFill.setFill()
    batteryBody.fill()
    batteryBody.lineWidth = 8
    panelStroke.setStroke()
    batteryBody.stroke()

    let terminal = roundedRect(NSRect(x: 746, y: 526, width: 86, height: 35), radius: 13)
    panelFill.setFill()
    terminal.fill()
    terminal.lineWidth = 6
    panelStroke.setStroke()
    terminal.stroke()

    let cellGradient = NSGradient(colors: [aqua, green])!
    for index in 0..<4 {
        let cell = roundedRect(
            NSRect(x: 727, y: 285 + CGFloat(index) * 57, width: 124, height: 43),
            radius: 13
        )
        fill(cell, gradient: cellGradient, angle: 0)
        cell.lineWidth = 2
        cellHighlight.setStroke()
        cell.stroke()
    }

    let bolt = NSBezierPath()
    bolt.move(to: NSPoint(x: 534, y: 407))
    bolt.line(to: NSPoint(x: 650, y: 407))
    bolt.line(to: NSPoint(x: 614, y: 344))
    bolt.line(to: NSPoint(x: 708, y: 440))
    bolt.line(to: NSPoint(x: 590, y: 440))
    bolt.line(to: NSPoint(x: 626, y: 505))
    bolt.close()
    fill(bolt, gradient: NSGradient(colors: [cyan, green])!, angle: 0)
    bolt.lineWidth = 5
    NSColor.white.withAlphaComponent(0.72).setStroke()
    bolt.stroke()

    NSGraphicsContext.restoreGraphicsState()
    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw CocoaError(.fileWriteUnknown)
    }
    return data
}

private func resizePNG(_ source: NSImage, pixels: Int) throws -> Data {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ), let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw CocoaError(.fileWriteUnknown)
    }
    bitmap.size = NSSize(width: pixels, height: pixels)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.imageInterpolation = .high
    source.draw(
        in: NSRect(x: 0, y: 0, width: pixels, height: pixels),
        from: NSRect(origin: .zero, size: source.size),
        operation: .copy,
        fraction: 1
    )
    NSGraphicsContext.restoreGraphicsState()
    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw CocoaError(.fileWriteUnknown)
    }
    return data
}

try FileManager.default.createDirectory(at: appearancesURL, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

let lightData = try drawIcon(.light)
let darkData = try drawIcon(.dark)
let foregroundData = try drawIcon(.light, includeBackground: false)
try lightData.write(to: appearancesURL.appendingPathComponent(Appearance.light.filename), options: .atomic)
try darkData.write(to: appearancesURL.appendingPathComponent(Appearance.dark.filename), options: .atomic)
try foregroundData.write(
    to: appearancesURL.appendingPathComponent("AppIcon-Foreground-1024.png"),
    options: .atomic
)
try lightData.write(to: resourcesURL.appendingPathComponent("AppIcon-master.png"), options: .atomic)

guard let lightImage = NSImage(data: lightData) else { throw CocoaError(.fileReadCorruptFile) }
let iconSizes: [(name: String, pixels: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]
for entry in iconSizes {
    let resized = try resizePNG(lightImage, pixels: entry.pixels)
    try resized.write(to: iconsetURL.appendingPathComponent(entry.name), options: .atomic)
}

print("Generated adaptive Drawstate icon artwork and legacy iconset.")
