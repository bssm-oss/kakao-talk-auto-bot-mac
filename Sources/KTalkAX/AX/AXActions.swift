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
            throw KTalkAXError.unsupported("입력창 값은 접근성 API로 직접 설정할 수 없습니다.")
        }
        try element.setAttribute(AXAttributeNames.value, value: text as CFString)
    }

    static func press(_ element: AXElement) throws {
        if try element.actionNames().contains(AXActionNames.press) {
            try element.performAction(AXActionNames.press)
            return
        }
        throw KTalkAXError.unsupported("이 요소는 AXPress 동작을 제공하지 않습니다.")
    }
}
