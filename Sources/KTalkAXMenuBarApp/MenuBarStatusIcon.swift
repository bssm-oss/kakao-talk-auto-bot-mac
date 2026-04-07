import AppKit
import Foundation
import KTalkAXCore

enum MenuBarStatusGlyph: String, CaseIterable {
    case idle
    case busy
    case permissionRequired
    case unavailable
    case attention
    case ready
}

enum MenuBarStatusTint: String {
    case neutral
    case accent
    case warning
    case error
    case success

    var color: NSColor {
        switch self {
        case .neutral:
            .labelColor
        case .accent:
            .controlAccentColor
        case .warning:
            .systemOrange
        case .error:
            .systemRed
        case .success:
            .systemGreen
        }
    }
}

struct MenuBarStatusItemAppearance {
    let glyph: MenuBarStatusGlyph
    let tint: MenuBarStatusTint
    let tooltip: String

    var tintColor: NSColor { tint.color }

    static let idle = MenuBarStatusItemAppearance(
        glyph: .idle,
        tint: .neutral,
        tooltip: "katalk-ax 메뉴 막대"
    )
}

enum MenuBarStatusAppearanceResolver {
    static func resolve(isBusy: Bool, latestStatus: StatusResult?) -> MenuBarStatusItemAppearance {
        resolve(
            isBusy: isBusy,
            permissionTrusted: latestStatus?.permission.trusted,
            kakaoTalkRunning: latestStatus?.kakaoTalkRunning,
            loginState: latestStatus?.loginState
        )
    }

    static func resolve(
        isBusy: Bool,
        permissionTrusted: Bool?,
        kakaoTalkRunning: Bool?,
        loginState: String?
    ) -> MenuBarStatusItemAppearance {
        if isBusy {
            return MenuBarStatusItemAppearance(
                glyph: .busy,
                tint: .accent,
                tooltip: "katalk-ax: 카카오톡 상태를 새로고침하는 중"
            )
        }

        guard let permissionTrusted, let kakaoTalkRunning, let loginState else {
            return MenuBarStatusItemAppearance(
                glyph: .idle,
                tint: .neutral,
                tooltip: "katalk-ax: 상태를 확인할 수 없음"
            )
        }

        if !permissionTrusted {
            return MenuBarStatusItemAppearance(
                glyph: .permissionRequired,
                tint: .error,
                tooltip: "katalk-ax: 접근성 권한 필요"
            )
        }

        if !kakaoTalkRunning {
            return MenuBarStatusItemAppearance(
                glyph: .unavailable,
                tint: .warning,
                tooltip: "katalk-ax: 카카오톡이 실행 중이 아님"
            )
        }

        if loginState != "ready" {
            return MenuBarStatusItemAppearance(
                glyph: .attention,
                tint: .warning,
                tooltip: "katalk-ax: 카카오톡 확인 필요"
            )
        }

        return MenuBarStatusItemAppearance(
            glyph: .ready,
            tint: .success,
            tooltip: "katalk-ax: 카카오톡 준비 완료"
        )
    }
}

@MainActor
enum MenuBarStatusItemIconFactory {
    private static let imageSize = NSSize(width: 18, height: 18)

    static func image(for appearance: MenuBarStatusItemAppearance) -> NSImage {
        let image = NSImage(size: imageSize, flipped: false) { bounds in
            drawConversationMark(for: appearance, in: bounds)
            return true
        }
        image.isTemplate = false
        return image
    }

    private static func drawConversationMark(for appearance: MenuBarStatusItemAppearance, in bounds: NSRect) {
        let grid = UnitGrid(bounds: bounds)
        let context = NSGraphicsContext.current?.cgContext

        NSColor.clear.setFill()
        bounds.fill()

        NSColor(calibratedWhite: 1.0, alpha: 1.0).setFill()
        conversationBubblePath(grid: grid).fill()

        NSColor(calibratedWhite: 0.0, alpha: 0.34).setStroke()
        let outline = conversationBubblePath(grid: grid)
        outline.lineWidth = grid.length(0.9)
        outline.stroke()

        context?.saveGState()
        context?.setBlendMode(.clear)
        drawCutoutGlyph(for: appearance.glyph, grid: grid)
        context?.restoreGState()

        drawStatusAccent(for: appearance, grid: grid)
    }

    private static func conversationBubblePath(grid: UnitGrid) -> NSBezierPath {
        let path = NSBezierPath()

        let backBubble = NSBezierPath(
            roundedRect: grid.rect(x: 2.25, y: 9.45, width: 7.05, height: 4.95),
            xRadius: grid.length(2.3),
            yRadius: grid.length(2.3)
        )
        path.append(backBubble)

        let frontBubbleRect = grid.rect(x: 5.05, y: 4.65, width: 10.1, height: 7.35)
        let frontBubble = NSBezierPath(
            roundedRect: frontBubbleRect,
            xRadius: grid.length(3.15),
            yRadius: grid.length(3.15)
        )
        path.append(frontBubble)

        let tail = NSBezierPath()
        tail.move(to: grid.point(x: 7.35, y: 4.65))
        tail.line(to: grid.point(x: 6.15, y: 2.1))
        tail.line(to: grid.point(x: 8.55, y: 4.65))
        tail.close()
        path.append(tail)

        return path
    }

    private static func drawCutoutGlyph(for glyph: MenuBarStatusGlyph, grid: UnitGrid) {
        switch glyph {
        case .idle, .ready:
            drawEllipsis(grid: grid)
            if glyph == .ready {
                drawCheck(grid: grid)
            }
        case .busy:
            drawTypingDots(grid: grid)
        case .permissionRequired, .attention:
            drawExclamation(grid: grid)
        case .unavailable:
            drawUnavailableSlash(grid: grid)
        }
    }

    private static func drawEllipsis(grid: UnitGrid) {
        for x in stride(from: CGFloat(7.25), through: CGFloat(11.25), by: 2) {
            NSBezierPath(ovalIn: grid.rect(x: x, y: 7.15, width: 1.45, height: 1.45)).fill()
        }
    }

    private static func drawTypingDots(grid: UnitGrid) {
        let positions: [(CGFloat, CGFloat)] = [
            (7.1, 6.8),
            (9.1, 7.45),
            (11.1, 6.55)
        ]

        for (x, y) in positions {
            NSBezierPath(ovalIn: grid.rect(x: x, y: y, width: 1.55, height: 1.55)).fill()
        }
    }

    private static func drawExclamation(grid: UnitGrid) {
        let stroke = NSBezierPath()
        stroke.move(to: grid.point(x: 9.95, y: 10.35))
        stroke.line(to: grid.point(x: 9.95, y: 6.45))
        stroke.lineWidth = grid.length(1.55)
        stroke.lineCapStyle = .round
        stroke.stroke()

        NSBezierPath(ovalIn: grid.rect(x: 9.15, y: 4.95, width: 1.6, height: 1.6)).fill()
    }

    private static func drawUnavailableSlash(grid: UnitGrid) {
        drawEllipsis(grid: grid)

        let stroke = NSBezierPath()
        stroke.move(to: grid.point(x: 12.8, y: 11.15))
        stroke.line(to: grid.point(x: 7.2, y: 5.2))
        stroke.lineWidth = grid.length(1.7)
        stroke.lineCapStyle = .round
        stroke.stroke()
    }

    private static func drawCheck(grid: UnitGrid) {
        let stroke = NSBezierPath()
        stroke.move(to: grid.point(x: 11.75, y: 12.8))
        stroke.line(to: grid.point(x: 13.15, y: 11.2))
        stroke.line(to: grid.point(x: 15.55, y: 13.95))
        stroke.lineWidth = grid.length(1.45)
        stroke.lineCapStyle = .round
        stroke.lineJoinStyle = .round
        stroke.stroke()
    }

    private static func drawStatusAccent(for appearance: MenuBarStatusItemAppearance, grid: UnitGrid) {
        let accentRect = grid.rect(x: 12.2, y: 1.0, width: 4.4, height: 4.4)
        let accentPath = NSBezierPath(ovalIn: accentRect)
        appearance.tintColor.setFill()
        accentPath.fill()

        NSColor(calibratedWhite: 0.0, alpha: 0.18).setStroke()
        accentPath.lineWidth = grid.length(0.9)
        accentPath.stroke()
    }
}

private struct UnitGrid {
    let bounds: NSRect
    private let base: CGFloat = 18

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
