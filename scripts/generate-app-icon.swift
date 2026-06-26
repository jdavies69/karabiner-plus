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
    let graphiteLine = NSColor(calibratedRed: 0.12, green: 0.14, blue: 0.17, alpha: 0.12)
    let accent = NSColor(calibratedRed: 0.93, green: 0.28, blue: 0.10, alpha: 1.0)
    func point(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
        NSPoint(x: scale(x), y: scale(y))
    }

    let keyboardShadow = NSShadow()
    keyboardShadow.shadowOffset = NSSize(width: 0, height: scale(-24))
    keyboardShadow.shadowBlurRadius = scale(58)
    keyboardShadow.shadowColor = NSColor(calibratedWhite: 0.0, alpha: 0.18)
    keyboardShadow.set()

    let keyboardPath = NSBezierPath(roundedRect: rect(100, 176, 824, 666), xRadius: scale(160), yRadius: scale(160))
    NSGradient(colors: [
        NSColor(calibratedRed: 1.00, green: 1.00, blue: 1.00, alpha: 0.82),
        NSColor(calibratedRed: 0.90, green: 0.95, blue: 0.98, alpha: 0.62),
        NSColor(calibratedRed: 0.72, green: 0.79, blue: 0.85, alpha: 0.48)
    ])?.draw(in: keyboardPath, angle: -34)

    keyboardShadow.shadowColor = .clear
    keyboardShadow.set()
    NSColor(calibratedWhite: 1.0, alpha: 0.62).setStroke()
    keyboardPath.lineWidth = scale(5)
    keyboardPath.stroke()

    graphiteLine.setStroke()
    keyboardPath.lineWidth = scale(4)
    keyboardPath.stroke()

    NSColor(calibratedWhite: 1.0, alpha: 0.72).setStroke()
    let keyboardHighlight = NSBezierPath()
    keyboardHighlight.move(to: point(196, 760))
    keyboardHighlight.line(to: point(810, 760))
    keyboardHighlight.lineWidth = scale(9)
    keyboardHighlight.lineCapStyle = .round
    keyboardHighlight.stroke()

    let keyFill = NSColor(calibratedRed: 0.98, green: 0.99, blue: 1.0, alpha: 0.56)
    let keyStroke = NSColor(calibratedRed: 0.11, green: 0.13, blue: 0.16, alpha: 0.10)
    let keys: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
        (188, 612, 132, 78), (350, 612, 110, 78), (490, 612, 110, 78), (630, 612, 110, 78), (770, 612, 78, 78),
        (188, 486, 104, 82), (322, 486, 122, 82), (474, 486, 122, 82), (626, 486, 122, 82), (778, 486, 82, 82),
        (188, 360, 146, 86), (364, 360, 112, 86), (506, 360, 112, 86), (648, 360, 112, 86), (790, 360, 72, 86),
        (188, 260, 218, 76), (436, 260, 320, 76), (786, 260, 72, 76)
    ]

    for key in keys {
        let keyPath = NSBezierPath(roundedRect: rect(key.0, key.1, key.2, key.3), xRadius: scale(17), yRadius: scale(17))
        keyFill.setFill()
        keyPath.fill()
        keyStroke.setStroke()
        keyPath.lineWidth = scale(4)
        keyPath.stroke()
    }

    NSGraphicsContext.saveGraphicsState()
    let carabinerCenter = point(346, 510)
    let carabinerTransform = NSAffineTransform()
    carabinerTransform.translateX(by: carabinerCenter.x, yBy: carabinerCenter.y)
    carabinerTransform.rotate(byDegrees: -7)
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
    carabinerShadow.shadowBlurRadius = scale(26)
    carabinerShadow.shadowColor = NSColor(calibratedWhite: 0.0, alpha: 0.24)
    carabinerShadow.set()
    NSColor(calibratedWhite: 1.0, alpha: 0.96).setFill()
    carabinerPath.fill()

    carabinerShadow.shadowColor = .clear
    carabinerShadow.set()
    graphite.setStroke()
    carabinerPath.lineWidth = scale(17)
    carabinerPath.stroke()
    NSColor(calibratedWhite: 1.0, alpha: 0.62).setStroke()
    carabinerPath.lineWidth = scale(6)
    carabinerPath.stroke()

    let gatePath = NSBezierPath()
    gatePath.move(to: point(390, 632))
    gatePath.curve(to: point(428, 388), controlPoint1: point(416, 574), controlPoint2: point(434, 458))
    graphite.setStroke()
    gatePath.lineWidth = scale(19)
    gatePath.lineCapStyle = .round
    gatePath.stroke()
    NSColor(calibratedWhite: 1.0, alpha: 0.92).setStroke()
    gatePath.lineWidth = scale(9)
    gatePath.stroke()

    for band in [(400, 538), (408, 478)] {
        let bandPath = NSBezierPath(roundedRect: rect(CGFloat(band.0), CGFloat(band.1), 92, 42), xRadius: scale(11), yRadius: scale(11))
        NSColor(calibratedWhite: 1.0, alpha: 0.98).setFill()
        bandPath.fill()
        graphite.setStroke()
        bandPath.lineWidth = scale(9)
        bandPath.stroke()
    }

    let rivetPath = NSBezierPath(ovalIn: rect(386, 332, 32, 32))
    graphite.setFill()
    rivetPath.fill()
    NSColor(calibratedWhite: 1.0, alpha: 0.88).setFill()
    NSBezierPath(ovalIn: rect(396, 342, 12, 12)).fill()

    NSGraphicsContext.restoreGraphicsState()

    let plusShadow = NSShadow()
    plusShadow.shadowOffset = NSSize(width: 0, height: scale(-10))
    plusShadow.shadowBlurRadius = scale(22)
    plusShadow.shadowColor = NSColor(calibratedWhite: 0.0, alpha: 0.18)
    plusShadow.set()

    let plusPlate = NSBezierPath(roundedRect: rect(612, 356, 270, 270), xRadius: scale(76), yRadius: scale(76))
    NSGradient(colors: [
        NSColor(calibratedRed: 1.0, green: 1.0, blue: 1.0, alpha: 0.76),
        NSColor(calibratedRed: 0.86, green: 0.90, blue: 0.93, alpha: 0.62)
    ])?.draw(in: plusPlate, angle: -45)

    plusShadow.shadowColor = .clear
    plusShadow.set()
    graphiteLine.setStroke()
    plusPlate.lineWidth = scale(6)
    plusPlate.stroke()

    let horizontalPlus = NSBezierPath(roundedRect: rect(658, 468, 178, 58), xRadius: scale(29), yRadius: scale(29))
    let verticalPlus = NSBezierPath(roundedRect: rect(718, 408, 58, 178), xRadius: scale(29), yRadius: scale(29))
    graphite.setFill()
    horizontalPlus.fill()
    verticalPlus.fill()
    accent.withAlphaComponent(0.95).setFill()
    NSBezierPath(roundedRect: rect(718, 408, 58, 58), xRadius: scale(29), yRadius: scale(29)).fill()

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
