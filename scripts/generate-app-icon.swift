#!/usr/bin/env swift

import AppKit
import Foundation

let fileManager = FileManager.default
let repoRoot = URL(fileURLWithPath: fileManager.currentDirectoryPath, isDirectory: true)
let assetDirectory = repoRoot
    .appendingPathComponent("Assets", isDirectory: true)
let iconsetDirectory = assetDirectory.appendingPathComponent("KarabinerPlus.iconset", isDirectory: true)
let iconOutput = assetDirectory.appendingPathComponent("KarabinerPlus.icns")
let touchIconOutput = repoRoot.appendingPathComponent("public/apple-touch-icon.png")

try fileManager.createDirectory(at: assetDirectory, withIntermediateDirectories: true)
try? fileManager.removeItem(at: iconsetDirectory)
try fileManager.createDirectory(at: iconsetDirectory, withIntermediateDirectories: true)

func drawIcon(pixelSize: Int) throws -> Data {
    guard let representation = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelSize,
        pixelsHigh: pixelSize,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bitmapFormat: [],
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw NSError(domain: "KarabinerPlusIcon", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to create bitmap representation."])
    }

    representation.size = NSSize(width: pixelSize, height: pixelSize)

    guard let context = NSGraphicsContext(bitmapImageRep: representation) else {
        throw NSError(domain: "KarabinerPlusIcon", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unable to create graphics context."])
    }

    let size = CGFloat(pixelSize)
    func scale(_ value: CGFloat) -> CGFloat { value * size / 1024 }
    func rect(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> NSRect {
        NSRect(x: scale(x), y: scale(y), width: scale(width), height: scale(height))
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.imageInterpolation = .high

    NSColor.clear.setFill()
    NSRect(x: 0, y: 0, width: size, height: size).fill()

    let graphite = NSColor(calibratedRed: 0.12, green: 0.14, blue: 0.17, alpha: 1.0)
    let accent = NSColor(calibratedRed: 0.93, green: 0.28, blue: 0.10, alpha: 1.0)
    func point(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
        NSPoint(x: scale(x), y: scale(y))
    }

    let keyFill = NSColor(calibratedRed: 0.92, green: 0.96, blue: 0.99, alpha: 0.42)
    let keyStroke = NSColor(calibratedRed: 0.11, green: 0.13, blue: 0.16, alpha: 0.10)
    let keys: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
        (500, 672, 118, 76), (648, 672, 118, 76), (796, 672, 88, 76),
        (520, 536, 128, 80), (680, 536, 128, 80), (838, 536, 72, 80),
        (522, 392, 154, 84), (708, 392, 146, 84),
        (516, 254, 292, 82), (842, 254, 72, 82)
    ]

    for key in keys {
        let keyPath = NSBezierPath(roundedRect: rect(key.0, key.1, key.2, key.3), xRadius: scale(17), yRadius: scale(17))
        let keyShadow = NSShadow()
        keyShadow.shadowOffset = NSSize(width: 0, height: scale(-6))
        keyShadow.shadowBlurRadius = scale(12)
        keyShadow.shadowColor = NSColor(calibratedWhite: 0.0, alpha: 0.08)
        keyShadow.set()
        keyFill.setFill()
        keyPath.fill()
        keyShadow.shadowColor = .clear
        keyShadow.set()
        keyStroke.setStroke()
        keyPath.lineWidth = scale(4)
        keyPath.stroke()
    }

    NSGraphicsContext.saveGraphicsState()
    let carabinerCenter = point(348, 510)
    let carabinerTransform = NSAffineTransform()
    carabinerTransform.translateX(by: carabinerCenter.x, yBy: carabinerCenter.y)
    carabinerTransform.scale(by: 1.12)
    carabinerTransform.rotate(byDegrees: -6)
    carabinerTransform.translateX(by: -carabinerCenter.x, yBy: -carabinerCenter.y)
    carabinerTransform.concat()

    let carabinerPath = NSBezierPath()
    carabinerPath.windingRule = .evenOdd
    carabinerPath.move(to: point(386, 724))
    carabinerPath.curve(to: point(210, 690), controlPoint1: point(314, 742), controlPoint2: point(236, 738))
    carabinerPath.curve(to: point(162, 352), controlPoint1: point(162, 604), controlPoint2: point(132, 424))
    carabinerPath.curve(to: point(300, 276), controlPoint1: point(178, 292), controlPoint2: point(224, 260))
    carabinerPath.curve(to: point(478, 352), controlPoint1: point(382, 286), controlPoint2: point(450, 292))
    carabinerPath.curve(to: point(512, 616), controlPoint1: point(500, 424), controlPoint2: point(516, 532))
    carabinerPath.curve(to: point(386, 724), controlPoint1: point(506, 682), controlPoint2: point(452, 730))
    carabinerPath.close()

    carabinerPath.move(to: point(354, 640))
    carabinerPath.curve(to: point(266, 610), controlPoint1: point(318, 648), controlPoint2: point(282, 640))
    carabinerPath.curve(to: point(236, 406), controlPoint1: point(232, 550), controlPoint2: point(220, 454))
    carabinerPath.curve(to: point(314, 354), controlPoint1: point(248, 370), controlPoint2: point(274, 350))
    carabinerPath.curve(to: point(404, 408), controlPoint1: point(360, 358), controlPoint2: point(392, 372))
    carabinerPath.curve(to: point(432, 590), controlPoint1: point(420, 464), controlPoint2: point(438, 546))
    carabinerPath.curve(to: point(354, 640), controlPoint1: point(428, 626), controlPoint2: point(390, 650))
    carabinerPath.close()

    let carabinerShadow = NSShadow()
    carabinerShadow.shadowOffset = NSSize(width: scale(12), height: scale(-16))
    carabinerShadow.shadowBlurRadius = scale(34)
    carabinerShadow.shadowColor = NSColor(calibratedWhite: 0.0, alpha: 0.28)
    carabinerShadow.set()
    NSColor(calibratedWhite: 1.0, alpha: 0.96).setFill()
    carabinerPath.fill()

    carabinerShadow.shadowColor = .clear
    carabinerShadow.set()
    graphite.setStroke()
    carabinerPath.lineWidth = scale(20)
    carabinerPath.stroke()
    NSColor(calibratedWhite: 1.0, alpha: 0.62).setStroke()
    carabinerPath.lineWidth = scale(7)
    carabinerPath.stroke()

    let gatePath = NSBezierPath()
    gatePath.move(to: point(390, 632))
    gatePath.curve(to: point(428, 388), controlPoint1: point(416, 574), controlPoint2: point(434, 458))
    graphite.setStroke()
    gatePath.lineWidth = scale(21)
    gatePath.lineCapStyle = .round
    gatePath.stroke()
    NSColor(calibratedWhite: 1.0, alpha: 0.92).setStroke()
    gatePath.lineWidth = scale(10)
    gatePath.stroke()

    for band in [(400, 538), (408, 478)] {
        let bandPath = NSBezierPath(roundedRect: rect(CGFloat(band.0), CGFloat(band.1), 92, 42), xRadius: scale(11), yRadius: scale(11))
        NSColor(calibratedWhite: 1.0, alpha: 0.98).setFill()
        bandPath.fill()
        graphite.setStroke()
        bandPath.lineWidth = scale(10)
        bandPath.stroke()
    }

    let rivetPath = NSBezierPath(ovalIn: rect(386, 332, 32, 32))
    graphite.setFill()
    rivetPath.fill()
    NSColor(calibratedWhite: 1.0, alpha: 0.88).setFill()
    NSBezierPath(ovalIn: rect(396, 342, 12, 12)).fill()

    NSGraphicsContext.restoreGraphicsState()

    let plusShadow = NSShadow()
    plusShadow.shadowOffset = NSSize(width: 0, height: scale(-12))
    plusShadow.shadowBlurRadius = scale(26)
    plusShadow.shadowColor = NSColor(calibratedWhite: 0.0, alpha: 0.22)
    plusShadow.set()

    let horizontalPlus = NSBezierPath(roundedRect: rect(636, 460, 236, 74), xRadius: scale(37), yRadius: scale(37))
    let verticalPlus = NSBezierPath(roundedRect: rect(717, 379, 74, 236), xRadius: scale(37), yRadius: scale(37))
    accent.setFill()
    horizontalPlus.fill()
    verticalPlus.fill()
    plusShadow.shadowColor = .clear
    plusShadow.set()

    NSColor(calibratedWhite: 1.0, alpha: 0.72).setFill()
    NSBezierPath(roundedRect: rect(664, 484, 180, 26), xRadius: scale(13), yRadius: scale(13)).fill()
    NSBezierPath(roundedRect: rect(741, 407, 26, 180), xRadius: scale(13), yRadius: scale(13)).fill()

    NSGraphicsContext.restoreGraphicsState()

    guard let pngData = representation.representation(using: .png, properties: [.compressionFactor: 0.95]) else {
        throw NSError(domain: "KarabinerPlusIcon", code: 3, userInfo: [NSLocalizedDescriptionKey: "Unable to encode PNG data."])
    }

    return pngData
}

let iconsetFiles: [(name: String, size: Int)] = [
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

for icon in iconsetFiles {
    let data = try drawIcon(pixelSize: icon.size)
    try data.write(to: iconsetDirectory.appendingPathComponent(icon.name))
}

try drawIcon(pixelSize: 180).write(to: touchIconOutput)

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetDirectory.path, "-o", iconOutput.path]
try process.run()
process.waitUntilExit()

guard process.terminationStatus == 0 else {
    throw NSError(domain: "KarabinerPlusIcon", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "iconutil failed."])
}

try? fileManager.removeItem(at: iconsetDirectory)
print("Generated \(iconOutput.path)")
print("Generated \(touchIconOutput.path)")
