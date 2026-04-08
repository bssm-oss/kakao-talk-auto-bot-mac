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
        let nodes = try AXTraversal.collect(root: window, strategy: .breadthFirst, maxDepth: 7, maxNodes: 1400, timeout: 4.0)
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
        if !noCache, let cached = try cache?.resolve(cache?.store.sendButton, within: window), isConfidentSendButton(cached, near: composeField) {
            logger.trace("Using cached send button path")
            return (cached, cache?.store.sendButton)
        }

        let composeFrame = try composeField.frame()
        let nodes = try AXTraversal.collect(root: window, strategy: .breadthFirst, maxDepth: 7, maxNodes: 1400, timeout: 4.0)
        let scoredCandidates = nodes.compactMap { node -> (node: AXTraversalNode, score: Int)? in
            guard node.role == AXRoleNames.button else { return nil }
            let score = scoreSendButtonCandidate(node, near: composeFrame)
            return score > 0 ? (node, score) : nil
        }
        .sorted { lhs, rhs in
            if lhs.score == rhs.score {
                let lhsX = lhs.node.frame?.midX ?? 0
                let rhsX = rhs.node.frame?.midX ?? 0
                return lhsX > rhsX
            }
            return lhs.score > rhs.score
        }

        guard let best = scoredCandidates.first else {
            logger.trace("No confident send button found; will fall back to Enter key send")
            return (nil, nil)
        }

        logger.trace("Selected send button candidate score=\(best.score) path=\(best.node.path) title=\(best.node.title ?? "")")
        if best.score < 100 {
            logger.trace("No strong send-button signal; preferring Enter fallback over risky nearby button")
            return (nil, nil)
        }

        return (best.node.element, StoredAXPath(path: best.node.path, segments: KakaoTalkCache.capture(node: best.node).segments, capturedAt: Date()))
    }

    func composeMessage(_ message: String, in composeField: AXElement, speed: SendSpeed, dryRun: Bool) throws -> [String] {
        var usedFallbacks: [String] = []
        try AXActions.focus(composeField)
        Timeout.sleep(for: speed, base: 0.08)

        if try composeField.isAttributeSettable(AXAttributeNames.value) {
            do {
                try AXActions.setText(message, on: composeField)
                Timeout.sleep(for: speed, base: 0.08)
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
            Timeout.sleep(for: speed, base: 0.15)
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
                Timeout.sleep(for: speed, base: 0.08)
                return usedFallbacks
            } catch {
                logger.trace("Send button press failed: \(error.localizedDescription)")
            }
        }
        try Keyboard.enter()
        usedFallbacks.append("enter")
        Timeout.sleep(for: speed, base: 0.08)
        return usedFallbacks
    }

    private func isConfidentSendButton(_ element: AXElement, near composeField: AXElement) -> Bool {
        let node = AXTraversalNode(
            element: element,
            depth: 0,
            path: "cached-send-button",
            siblingIndex: 0,
            frame: try? element.frame(),
            role: try? element.role(),
            subrole: try? element.subrole(),
            title: try? element.title(),
            value: try? element.valueAsString()
        )
        let composeFrame = try? composeField.frame()
        return scoreSendButtonCandidate(node, near: composeFrame) >= 100
    }

    private func scoreSendButtonCandidate(_ node: AXTraversalNode, near composeFrame: CGRect?) -> Int {
        guard let buttonFrame = node.frame, let composeFrame else { return 0 }

        let texts = [
            node.title,
            node.value,
            try? node.element.stringAttribute(AXAttributeNames.description)
        ].compactMap { $0?.lowercased() }
        let combined = texts.joined(separator: " ") + " " + node.path.lowercased()

        if containsAny(combined, needles: ["file", "파일", "attach", "첨부", "사진", "image", "photo", "plus", "upload", "clip", "paperclip"]) {
            return 0
        }

        var score = 0
        if containsAny(combined, needles: ["send", "보내"]) {
            score += 200
        }

        let deltaY = abs(buttonFrame.midY - composeFrame.midY)
        let deltaX = buttonFrame.midX - composeFrame.midX
        if deltaX > 0 && deltaY < 40 {
            score += 70
        } else if deltaX > 0 && deltaY < 70 {
            score += 30
        }

        if buttonFrame.maxX > composeFrame.maxX {
            score += 10
        }

        return score
    }

    private func containsAny(_ haystack: String, needles: [String]) -> Bool {
        needles.contains { haystack.contains($0) }
    }
}
