import CoreGraphics
import Foundation

struct WindowDescriptor {
    let index: Int
    let element: AXElement
    let title: String
    let frame: CGRect?
    let isListWindow: Bool
    let isChatWindow: Bool
}

final class KakaoTalkWindows {
    private let logger: Logger

    init(logger: Logger) {
        self.logger = logger
    }

    func descriptors(appElement: AXElement) throws -> [WindowDescriptor] {
        var uniqueWindows = try appElement.windows()
        if let focused = try appElement.focusedWindow(),
           (try? focused.role()) == AXRoleNames.window,
           !uniqueWindows.contains(focused) {
            uniqueWindows.append(focused)
        }

        return try uniqueWindows.enumerated().map { index, window in
            let title = try window.title() ?? "window[\(index)]"
            let nodes = try AXTraversal.collect(root: window, strategy: .breadthFirst, maxDepth: 4, maxNodes: 250)
            let hasTopEditable = nodes.contains { node in
                guard let role = node.role, role == AXRoleNames.textField || role == AXRoleNames.textArea else { return false }
                guard let frame = node.frame, let windowFrame = try? window.frame() else { return true }
                return frame.midY < windowFrame.midY
            }
            let hasBottomEditable = nodes.contains { node in
                guard let role = node.role, role == AXRoleNames.textField || role == AXRoleNames.textArea else { return false }
                guard let frame = node.frame, let windowFrame = try? window.frame() else { return false }
                return frame.midY > windowFrame.midY
            }
            let hasRows = nodes.contains { $0.role == AXRoleNames.row }
            let hasRowContainerEvidence = nodes.contains { node in
                guard [AXRoleNames.table, AXRoleNames.outline, AXRoleNames.list, AXRoleNames.scrollArea, AXRoleNames.group].contains(node.role ?? "") else { return false }
                if let rows = try? node.element.elementsAttribute(AXAttributeNames.rows), !rows.isEmpty { return true }
                if let rows = try? node.element.elementsAttribute(AXAttributeNames.visibleRows), !rows.isEmpty { return true }
                return false
            }
            let isListWindow = (hasRows || hasRowContainerEvidence) && (hasTopEditable || !hasBottomEditable)
            let descriptor = WindowDescriptor(
                index: index,
                element: window,
                title: title,
                frame: try window.frame(),
                isListWindow: isListWindow,
                isChatWindow: hasBottomEditable
            )
            logger.trace("Window[\(index)] title='\(title)' list=\(descriptor.isListWindow) chat=\(descriptor.isChatWindow)")
            return descriptor
        }
    }

    func primaryListWindow(appElement: AXElement) throws -> WindowDescriptor {
        let descriptors = try descriptors(appElement: appElement)
        if descriptors.isEmpty {
            throw KTalkAXError.invalidUI("카카오톡 메인 목록 창이 닫혀 있습니다. Dock 또는 메뉴 막대에서 카카오톡 창을 먼저 열어 주세요.")
        }
        if let focused = try appElement.focusedWindow(),
           let match = descriptors.first(where: { $0.element == focused && $0.isListWindow }) {
            return match
        }
        if let match = descriptors.first(where: { $0.isListWindow }) {
            return match
        }
        if let focused = try appElement.focusedWindow(),
           let match = descriptors.first(where: { $0.element == focused }) {
            return match
        }
        if let only = descriptors.first, descriptors.count == 1 {
            return only
        }
        throw KTalkAXError.invalidUI("채팅 목록처럼 보이는 KakaoTalk 창을 찾지 못했습니다.")
    }

    func chatWindow(appElement: AXElement, expectedTitle: String) throws -> WindowDescriptor? {
        let normalizedExpected = TextNormalizer.normalize(expectedTitle)
        let strippedExpected = TextNormalizer.normalize(expectedTitle, stripSeparators: true)
        return try descriptors(appElement: appElement).first(where: { descriptor in
            guard descriptor.isChatWindow else { return false }
            let normalizedTitle = TextNormalizer.normalize(descriptor.title)
            let strippedTitle = TextNormalizer.normalize(descriptor.title, stripSeparators: true)
            if normalizedTitle == normalizedExpected || strippedTitle == strippedExpected {
                return true
            }
            return (try? windowContainsExpectedChatSignal(descriptor.element, normalizedExpected: normalizedExpected, strippedExpected: strippedExpected)) == true
        })
    }

    private func windowContainsExpectedChatSignal(_ window: AXElement, normalizedExpected: String, strippedExpected: String) throws -> Bool {
        let nodes = try AXTraversal.collect(root: window, strategy: .breadthFirst, maxDepth: 5, maxNodes: 400, timeout: 3.0)
        return nodes.contains { node in
            let candidateTexts = [node.title, node.value, try? node.element.stringAttribute(AXAttributeNames.description)].compactMap { $0 }
            return candidateTexts.contains { text in
                let normalized = TextNormalizer.normalize(text)
                let stripped = TextNormalizer.normalize(text, stripSeparators: true)
                return normalized == normalizedExpected || stripped == strippedExpected
            }
        }
    }

    func close(window: AXElement) throws {
        if let closeButton = try window.elementAttribute(AXAttributeNames.closeButton) {
            do {
                try AXActions.press(closeButton)
                return
            } catch {
                logger.trace("AX close button press failed: \(error.localizedDescription)")
            }
        }
        try AXActions.focus(window)
        try Keyboard.closeWindow()
    }
}
