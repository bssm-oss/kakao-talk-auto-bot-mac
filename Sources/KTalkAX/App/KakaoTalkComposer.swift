import Foundation

final class KakaoTalkComposer {
    private let logger: Logger

    init(logger: Logger) {
        self.logger = logger
    }

    func findComposeField(in window: AXElement, cache: KakaoTalkCache?, noCache: Bool) throws -> (AXElement, StoredAXPath?) {
        if !noCache, let cached = try cache?.resolve(cache?.store.composeField, within: window) {
            logger.trace("Using cached compose field path")
            return (cached, cache?.store.composeField)
        }
        let nodes = try AXTraversal.collect(root: window, strategy: .breadthFirst, maxDepth: 8, maxNodes: 2500, timeout: 8.0)
        let candidates = nodes.filter { node in
            guard let role = node.role, role == AXRoleNames.textArea || role == AXRoleNames.textField else { return false }
            guard let frame = node.frame, let windowFrame = try? window.frame() else { return false }
            return frame.midY > windowFrame.midY
        }
        let sortedCandidates = candidates.sorted { lhs, rhs in
            (lhs.frame?.midY ?? 0) > (rhs.frame?.midY ?? 0)
        }
        guard let best = sortedCandidates.first else {
            throw KTalkAXError.composeFieldNotFound("현재 채팅창에서 메시지 입력창을 찾지 못했습니다.")
        }
        return (best.element, StoredAXPath(path: best.path, segments: KakaoTalkCache.capture(node: best).segments, capturedAt: Date()))
    }

    func findSendButton(near composeField: AXElement, in window: AXElement, cache: KakaoTalkCache?, noCache: Bool) throws -> (AXElement?, StoredAXPath?) {
        if !noCache, let cached = try cache?.resolve(cache?.store.sendButton, within: window) {
            logger.trace("Using cached send button path")
            return (cached, cache?.store.sendButton)
        }
        let composeFrame = try composeField.frame()
        let nodes = try AXTraversal.collect(root: window, strategy: .breadthFirst, maxDepth: 8, maxNodes: 2500, timeout: 8.0)
        let candidates = nodes.filter { node in
            guard node.role == AXRoleNames.button else { return false }
            if let title = node.title?.lowercased(), title.contains("send") || title.contains("보내") { return true }
            guard let buttonFrame = node.frame, let composeFrame else { return false }
            return abs(buttonFrame.midY - composeFrame.midY) < 80 && buttonFrame.midX > composeFrame.midX
        }
        guard let best = candidates.first else {
            return (nil, nil)
        }
        return (best.element, StoredAXPath(path: best.path, segments: KakaoTalkCache.capture(node: best).segments, capturedAt: Date()))
    }

    func composeMessage(_ message: String, in composeField: AXElement, speed: SendSpeed, dryRun: Bool) throws -> [String] {
        var usedFallbacks: [String] = []
        try AXActions.focus(composeField)
        Timeout.sleep(for: speed)

        if try composeField.isAttributeSettable(AXAttributeNames.value) {
            do {
                try AXActions.setText(message, on: composeField)
                Timeout.sleep(for: speed)
                let current = try composeField.valueAsString() ?? ""
                if current == message {
                    return usedFallbacks
                }
            } catch {
                logger.trace("Direct AX value set failed: \(error.localizedDescription)")
            }
        }

        if !dryRun {
            let snapshot = PasteboardWriter.backup()
            PasteboardWriter.write(string: message)
            try Keyboard.paste()
            Timeout.sleep(for: speed, base: 0.25)
            PasteboardWriter.restore(snapshot)
            usedFallbacks.append("pasteboard")
            let current = try composeField.valueAsString() ?? ""
            if current == message {
                return usedFallbacks
            }
        }

        try Keyboard.type(text: message)
        usedFallbacks.append("typing")
        return usedFallbacks
    }

    func sendMessage(button: AXElement?, speed: SendSpeed) throws -> [String] {
        var usedFallbacks: [String] = []
        if let button {
            do {
                try AXActions.press(button)
                Timeout.sleep(for: speed)
                return usedFallbacks
            } catch {
                logger.trace("Send button press failed: \(error.localizedDescription)")
            }
        }
        try Keyboard.enter()
        usedFallbacks.append("enter")
        Timeout.sleep(for: speed)
        return usedFallbacks
    }
}
