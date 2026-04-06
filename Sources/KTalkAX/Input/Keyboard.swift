import AppKit
import CoreGraphics
import Foundation

enum Keyboard {
    enum Key: CGKeyCode {
        case v = 9
        case returnKey = 36
        case escape = 53
        case a = 0
        case w = 13
        case delete = 51
        case forwardDelete = 117
    }

    static func press(_ key: Key, modifiers: CGEventFlags = []) throws {
        guard let source = CGEventSource(stateID: .combinedSessionState) else {
            throw KTalkAXError.sendFailed("Failed to create keyboard event source.")
        }
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: key.rawValue, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: key.rawValue, keyDown: false) else {
            throw KTalkAXError.sendFailed("Failed to create keyboard events.")
        }
        keyDown.flags = modifiers
        keyUp.flags = modifiers
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }

    static func paste() throws {
        try press(.v, modifiers: .maskCommand)
    }

    static func enter(shift: Bool = false) throws {
        try press(.returnKey, modifiers: shift ? .maskShift : [])
    }

    static func escape() throws {
        try press(.escape)
    }

    static func selectAllAndDelete() throws {
        try press(.a, modifiers: .maskCommand)
        Thread.sleep(forTimeInterval: 0.05)
        try press(.delete)
    }

    static func closeWindow() throws {
        try press(.w, modifiers: .maskCommand)
    }

    static func type(text: String) throws {
        guard let source = CGEventSource(stateID: .combinedSessionState) else {
            throw KTalkAXError.sendFailed("Failed to create keyboard event source.")
        }
        for scalar in text.unicodeScalars {
            var utf16 = Array(String(scalar).utf16)
            guard let eventDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
                  let eventUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else {
                continue
            }
            eventDown.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: &utf16)
            eventUp.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: &utf16)
            eventDown.post(tap: .cghidEventTap)
            eventUp.post(tap: .cghidEventTap)
        }
    }
}
