import ApplicationServices
import CoreGraphics
import Foundation

struct AXElement: Hashable {
    let rawValue: AXUIElement

    static func == (lhs: AXElement, rhs: AXElement) -> Bool {
        CFEqual(lhs.rawValue, rhs.rawValue)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(CFHash(rawValue))
    }

    static func appElement(pid: pid_t) -> AXElement {
        AXElement(rawValue: AXUIElementCreateApplication(pid))
    }

    static func systemWideElement() -> AXElement {
        AXElement(rawValue: AXUIElementCreateSystemWide())
    }

    func attributeNames() throws -> [String] {
        var names: CFArray?
        let error = AXUIElementCopyAttributeNames(rawValue, &names)
        try throwIfNeeded(error, context: "attribute names")
        return names as? [String] ?? []
    }

    func actionNames() throws -> [String] {
        var names: CFArray?
        let error = AXUIElementCopyActionNames(rawValue, &names)
        try throwIfNeeded(error, context: "action names")
        return names as? [String] ?? []
    }

    func attribute<T>(_ name: String) throws -> T? {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(rawValue, name as CFString, &value)
        if error == .noValue { return nil }
        try throwIfNeeded(error, context: name)
        return value as? T
    }

    func stringAttribute(_ name: String) throws -> String? {
        if let string: NSString = try attribute(name) {
            return string as String
        }
        if let number: NSNumber = try attribute(name) {
            return number.stringValue
        }
        if let value: AXValue = try attribute(name), AXValueGetType(value) == .cfRange {
            var range = CFRange()
            AXValueGetValue(value, .cfRange, &range)
            return "{location=\(range.location),length=\(range.length)}"
        }
        return nil
    }

    func boolAttribute(_ name: String) throws -> Bool? {
        (try attribute(name) as NSNumber?)?.boolValue
    }

    func intAttribute(_ name: String) throws -> Int? {
        (try attribute(name) as NSNumber?)?.intValue
    }

    func elementAttribute(_ name: String) throws -> AXElement? {
        if let value: AXUIElement = try attribute(name) {
            return AXElement(rawValue: value)
        }
        return nil
    }

    func elementsAttribute(_ name: String) throws -> [AXElement] {
        guard let values: [AXUIElement] = try attribute(name) else { return [] }
        return values.map { AXElement(rawValue: $0) }
    }

    func setAttribute(_ name: String, value: CFTypeRef) throws {
        let error = AXUIElementSetAttributeValue(rawValue, name as CFString, value)
        try throwIfNeeded(error, context: name)
    }

    func isAttributeSettable(_ name: String) throws -> Bool {
        var value = DarwinBoolean(false)
        let error = AXUIElementIsAttributeSettable(rawValue, name as CFString, &value)
        try throwIfNeeded(error, context: "is settable \(name)")
        return value.boolValue
    }

    func performAction(_ name: String) throws {
        let error = AXUIElementPerformAction(rawValue, name as CFString)
        try throwIfNeeded(error, context: name)
    }

    func frame() throws -> CGRect? {
        guard let positionValue: AXValue = try attribute(AXAttributeNames.position),
              let sizeValue: AXValue = try attribute(AXAttributeNames.size) else {
            return nil
        }
        var point = CGPoint.zero
        var size = CGSize.zero
        AXValueGetValue(positionValue, .cgPoint, &point)
        AXValueGetValue(sizeValue, .cgSize, &size)
        return CGRect(origin: point, size: size)
    }

    func pid() throws -> pid_t {
        var pid: pid_t = 0
        let error = AXUIElementGetPid(rawValue, &pid)
        try throwIfNeeded(error, context: "pid")
        return pid
    }

    func role() throws -> String? { try stringAttribute(AXAttributeNames.role) }
    func subrole() throws -> String? { try stringAttribute(AXAttributeNames.subrole) }
    func title() throws -> String? { try stringAttribute(AXAttributeNames.title) }
    func valueAsString() throws -> String? { try stringAttribute(AXAttributeNames.value) }
    func children() throws -> [AXElement] { try elementsAttribute(AXAttributeNames.children) }
    func parent() throws -> AXElement? { try elementAttribute(AXAttributeNames.parent) }
    func window() throws -> AXElement? {
        var current: AXElement? = self
        while let element = current {
            if try element.role() == AXRoleNames.window {
                return element
            }
            current = try element.parent()
        }
        return nil
    }
    func focusedWindow() throws -> AXElement? { try elementAttribute(AXAttributeNames.focusedWindow) }
    func windows() throws -> [AXElement] { try elementsAttribute(AXAttributeNames.windows) }

    private func throwIfNeeded(_ error: AXError, context: String) throws {
        guard error != .success else { return }
        switch error {
        case .attributeUnsupported, .actionUnsupported:
            throw KTalkAXError.unsupported("Accessibility does not support \(context) on this element.")
        case .cannotComplete:
            throw KTalkAXError.cannotComplete("Accessibility could not complete \(context).")
        case .notImplemented:
            throw KTalkAXError.unsupported("Accessibility API is not implemented for \(context).")
        case .invalidUIElement, .invalidUIElementObserver:
            throw KTalkAXError.invalidUI("Invalid accessibility element while accessing \(context).")
        case .apiDisabled:
            throw KTalkAXError.notTrusted(prompted: false)
        case .noValue:
            throw KTalkAXError.noValue("Accessibility has no value for \(context).")
        default:
            throw KTalkAXError.generic("Accessibility error \(error.rawValue) while accessing \(context).")
        }
    }
}
