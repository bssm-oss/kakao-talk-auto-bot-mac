import CoreGraphics
import Foundation

enum Mouse {
    static func click(centerOf rect: CGRect) throws {
        try click(centerOf: rect, clickCount: 1)
    }

    static func doubleClick(centerOf rect: CGRect) throws {
        try click(centerOf: rect, clickCount: 2)
    }

    private static func click(centerOf rect: CGRect, clickCount: Int) throws {
        let point = CGPoint(x: rect.midX, y: rect.midY)
        guard let move = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left),
              let down = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left),
              let up = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left) else {
            throw KTalkAXError.sendFailed("마우스 이벤트를 만들지 못했습니다.")
        }
        for count in 1...clickCount {
            move.post(tap: .cghidEventTap)
            down.setIntegerValueField(.mouseEventClickState, value: Int64(count))
            up.setIntegerValueField(.mouseEventClickState, value: Int64(count))
            down.post(tap: .cghidEventTap)
            up.post(tap: .cghidEventTap)
            Thread.sleep(forTimeInterval: 0.05)
        }
    }
}
