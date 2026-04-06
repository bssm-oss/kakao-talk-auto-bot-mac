import Foundation

enum AXActions {
    static func focus(_ element: AXElement) throws {
        if try element.actionNames().contains(AXActionNames.raise) {
            try element.performAction(AXActionNames.raise)
            return
        }
        if try element.isAttributeSettable(AXAttributeNames.focused) {
            try element.setAttribute(AXAttributeNames.focused, value: kCFBooleanTrue)
        }
    }

    static func clearText(_ element: AXElement) throws {
        if try element.isAttributeSettable(AXAttributeNames.value) {
            try element.setAttribute(AXAttributeNames.value, value: "" as CFString)
        }
    }

    static func setText(_ text: String, on element: AXElement) throws {
        guard try element.isAttributeSettable(AXAttributeNames.value) else {
            throw KTalkAXError.unsupported("Compose field is not settable through Accessibility.")
        }
        try element.setAttribute(AXAttributeNames.value, value: text as CFString)
    }

    static func press(_ element: AXElement) throws {
        if try element.actionNames().contains(AXActionNames.press) {
            try element.performAction(AXActionNames.press)
            return
        }
        throw KTalkAXError.unsupported("Element does not expose AXPress.")
    }
}
