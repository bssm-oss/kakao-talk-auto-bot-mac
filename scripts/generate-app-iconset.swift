import AppKit
import Foundation

private struct IconsetEntry {
    let fileName: String
    let pixelSize: Int

    static let all: [IconsetEntry] = [
        IconsetEntry(fileName: "icon_16x16.png", pixelSize: 16),
        IconsetEntry(fileName: "icon_16x16@2x.png", pixelSize: 32),
        IconsetEntry(fileName: "icon_32x32.png", pixelSize: 32),
        IconsetEntry(fileName: "icon_32x32@2x.png", pixelSize: 64),
        IconsetEntry(fileName: "icon_128x128.png", pixelSize: 128),
        IconsetEntry(fileName: "icon_128x128@2x.png", pixelSize: 256),
        IconsetEntry(fileName: "icon_256x256.png", pixelSize: 256),
        IconsetEntry(fileName: "icon_256x256@2x.png", pixelSize: 512),
        IconsetEntry(fileName: "icon_512x512.png", pixelSize: 512),
        IconsetEntry(fileName: "icon_512x512@2x.png", pixelSize: 1024)
    ]
}

private enum GeneratorError: Error, LocalizedError {
    case missingOutputDirectory
    case invalidArguments(String)
    case bitmapContextUnavailable(Int)
    case pngEncodingFailed(Int)

    var errorDescription: String? {
        switch self {
        case .missingOutputDirectory:
            "Missing required --output-dir argument"
        case .invalidArguments(let message):
            message
        case .bitmapContextUnavailable(let pixelSize):
            "Failed to create bitmap context for \(pixelSize)x\(pixelSize) icon"
        case .pngEncodingFailed(let pixelSize):
            "Failed to encode \(pixelSize)x\(pixelSize) icon as PNG"
        }
    }
}

private func parseOutputDirectory(from arguments: ArraySlice<String>) throws -> URL {
    guard !arguments.isEmpty else {
        throw GeneratorError.missingOutputDirectory
    }

    let values = Array(arguments)
    guard values.count == 2 else {
        throw GeneratorError.invalidArguments("Usage: swift scripts/generate-app-iconset.swift --output-dir <path>")
    }

    guard values[0] == "--output-dir" else {
        throw GeneratorError.invalidArguments("Unknown argument: \(values[0])")
    }

    return URL(fileURLWithPath: values[1], isDirectory: true)
}

let outputDirectory = try parseOutputDirectory(from: CommandLine.arguments.dropFirst())
try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

for entry in IconsetEntry.all {
    let data = try AppIconRenderer.pngData(pixelSize: entry.pixelSize)
    let outputURL = outputDirectory.appendingPathComponent(entry.fileName)
    try data.write(to: outputURL, options: .atomic)
}

private enum AppIconRenderer {
    static func pngData(pixelSize: Int) throws -> Data {
        guard let representation = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelSize,
            pixelsHigh: pixelSize,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            throw GeneratorError.bitmapContextUnavailable(pixelSize)
        }

        representation.size = NSSize(width: pixelSize, height: pixelSize)
        guard let context = NSGraphicsContext(bitmapImageRep: representation) else {
            throw GeneratorError.bitmapContextUnavailable(pixelSize)
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.imageInterpolation = .high
        draw(in: NSRect(x: 0, y: 0, width: pixelSize, height: pixelSize))
        NSGraphicsContext.restoreGraphicsState()

        guard let data = representation.representation(using: .png, properties: [:]) else {
            throw GeneratorError.pngEncodingFailed(pixelSize)
        }

        return data
    }

    private static func draw(in bounds: NSRect) {
        let grid = UnitGrid(bounds: bounds)
        let canvas = bounds.insetBy(dx: grid.length(52), dy: grid.length(52))
        let cornerRadius = grid.length(164)
        let canvasPath = NSBezierPath(roundedRect: canvas, xRadius: cornerRadius, yRadius: cornerRadius)

        NSColor.clear.setFill()
        bounds.fill()

        let shadow = NSShadow()
        shadow.shadowColor = NSColor(calibratedWhite: 0, alpha: 0.16)
        shadow.shadowBlurRadius = grid.length(54)
        shadow.shadowOffset = NSSize(width: 0, height: -grid.length(18))
        shadow.set()

        let backgroundGradient = NSGradient(
            colors: [
                NSColor(srgbRed: 1.0, green: 0.925, blue: 0.46, alpha: 1),
                NSColor(srgbRed: 0.992, green: 0.734, blue: 0.248, alpha: 1)
            ]
        )!
        backgroundGradient.draw(in: canvasPath, angle: 90)

        let glossPath = NSBezierPath(roundedRect: canvas, xRadius: cornerRadius, yRadius: cornerRadius)
        glossPath.addClip()
        let glossGradient = NSGradient(
            colors: [
                NSColor(calibratedWhite: 1, alpha: 0.28),
                NSColor(calibratedWhite: 1, alpha: 0)
            ]
        )!
        glossGradient.draw(in: NSRect(
            x: canvas.minX,
            y: canvas.midY,
            width: canvas.width,
            height: canvas.height * 0.6
        ), angle: 90)

        NSColor(calibratedWhite: 0, alpha: 0.08).setStroke()
        canvasPath.lineWidth = grid.length(6)
        canvasPath.stroke()

        let backBubbleRect = grid.rect(x: 542, y: 558, width: 258, height: 208)
        let backBubbleColor = NSColor(srgbRed: 0.43, green: 0.275, blue: 0.19, alpha: 0.9)
        drawSpeechBubble(
            in: backBubbleRect,
            tail: [
                grid.point(x: 710, y: 556),
                grid.point(x: 736, y: 490),
                grid.point(x: 652, y: 548)
            ],
            fillColor: backBubbleColor,
            strokeColor: NSColor(calibratedWhite: 1, alpha: 0.12),
            strokeWidth: grid.length(7),
            cornerRadius: grid.length(74)
        )

        let frontBubbleRect = grid.rect(x: 212, y: 236, width: 566, height: 428)
        drawSpeechBubble(
            in: frontBubbleRect,
            tail: [
                grid.point(x: 364, y: 236),
                grid.point(x: 286, y: 110),
                grid.point(x: 470, y: 224)
            ],
            fillColor: NSColor(srgbRed: 0.164, green: 0.143, blue: 0.121, alpha: 0.98),
            strokeColor: NSColor(calibratedWhite: 1, alpha: 0.08),
            strokeWidth: grid.length(8),
            cornerRadius: grid.length(104)
        )

        let dotColor = NSColor(srgbRed: 1.0, green: 0.962, blue: 0.84, alpha: 0.98)
        dotColor.setFill()
        for frame in [
            grid.rect(x: 334, y: 395, width: 84, height: 84),
            grid.rect(x: 456, y: 395, width: 84, height: 84),
            grid.rect(x: 578, y: 395, width: 84, height: 84)
        ] {
            NSBezierPath(ovalIn: frame).fill()
        }

        let insetStroke = NSBezierPath(roundedRect: canvas.insetBy(dx: grid.length(10), dy: grid.length(10)), xRadius: cornerRadius * 0.88, yRadius: cornerRadius * 0.88)
        NSColor(calibratedWhite: 1, alpha: 0.12).setStroke()
        insetStroke.lineWidth = grid.length(4)
        insetStroke.stroke()
    }

    private static func drawSpeechBubble(
        in rect: NSRect,
        tail: [NSPoint],
        fillColor: NSColor,
        strokeColor: NSColor,
        strokeWidth: CGFloat,
        cornerRadius: CGFloat
    ) {
        let bubblePath = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
        let tailPath = NSBezierPath()
        tailPath.move(to: tail[0])
        tailPath.line(to: tail[1])
        tailPath.line(to: tail[2])
        tailPath.close()

        bubblePath.append(tailPath)

        fillColor.setFill()
        bubblePath.fill()

        strokeColor.setStroke()
        bubblePath.lineWidth = strokeWidth
        bubblePath.stroke()
    }
}

private struct UnitGrid {
    let bounds: NSRect
    private let base: CGFloat = 1024

    func length(_ value: CGFloat) -> CGFloat {
        bounds.width * value / base
    }

    func point(x: CGFloat, y: CGFloat) -> NSPoint {
        NSPoint(
            x: bounds.minX + bounds.width * x / base,
            y: bounds.minY + bounds.height * y / base
        )
    }

    func rect(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) -> NSRect {
        NSRect(
            x: bounds.minX + bounds.width * x / base,
            y: bounds.minY + bounds.height * y / base,
            width: bounds.width * width / base,
            height: bounds.height * height / base
        )
    }
}
