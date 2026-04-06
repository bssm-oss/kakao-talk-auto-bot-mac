import Foundation

struct ChatRowCandidate {
    let chatID: String
    let title: String
    let sourceWindow: String
    let matchableTexts: [String]
    let unreadEstimate: Int?
    let metaEstimate: String?
    let rowElement: AXElement
}

final class KakaoTalkSearchUI {
    private let logger: Logger

    init(logger: Logger) {
        self.logger = logger
    }

    func findSearchField(in window: AXElement, cache: KakaoTalkCache?, noCache: Bool) throws -> (AXElement, StoredAXPath?) {
        if !noCache, let cached = try cache?.resolve(cache?.store.searchField, within: window) {
            logger.trace("Using cached search field path")
            return (cached, cache?.store.searchField)
        }
        let nodes = try AXTraversal.collect(root: window, strategy: .breadthFirst, maxDepth: 5, maxNodes: 350)
        let candidates = nodes.filter { node in
            guard let role = node.role, role == AXRoleNames.textField || role == AXRoleNames.textArea else { return false }
            guard let frame = node.frame, let windowFrame = try? window.frame() else { return true }
            return frame.midY < windowFrame.midY
        }
        guard let best = candidates.first else {
            throw KTalkAXError.invalidUI("Search field not found. Run inspect to review the current AX tree.")
        }
        return (best.element, StoredAXPath(path: best.path, segments: KakaoTalkCache.capture(node: best).segments, capturedAt: Date()))
    }

    func clearAndTypeSearch(_ query: String, field: AXElement) throws {
        try AXActions.focus(field)
        Thread.sleep(forTimeInterval: 0.1)
        if try field.isAttributeSettable(AXAttributeNames.value) {
            try field.setAttribute(AXAttributeNames.value, value: "" as CFString)
            Thread.sleep(forTimeInterval: 0.05)
            try field.setAttribute(AXAttributeNames.value, value: query as CFString)
        } else {
            try Keyboard.selectAllAndDelete()
            try Keyboard.type(text: query)
        }
    }

    func findResultsContainer(in window: AXElement, cache: KakaoTalkCache?, noCache: Bool) throws -> (AXElement, StoredAXPath?) {
        if !noCache, let cached = try cache?.resolve(cache?.store.resultList, within: window) {
            logger.trace("Using cached result list path")
            return (cached, cache?.store.resultList)
        }
        let nodes = try AXTraversal.collect(root: window, strategy: .breadthFirst, maxDepth: 6, maxNodes: 500)
        let candidates = nodes.filter { node in
            [AXRoleNames.table, AXRoleNames.outline, AXRoleNames.list, AXRoleNames.scrollArea, AXRoleNames.group].contains(node.role ?? "")
        }
        let best = try candidates.first(where: { node in
            let descendants = try AXTraversal.collect(root: node.element, strategy: .breadthFirst, maxDepth: 3, maxNodes: 200)
            return descendants.contains(where: { $0.role == AXRoleNames.row })
        })
        guard let best else {
            throw KTalkAXError.invalidUI("Search results list was not found. Run inspect with --debug-layout for more detail.")
        }
        return (best.element, StoredAXPath(path: best.path, segments: KakaoTalkCache.capture(node: best).segments, capturedAt: Date()))
    }

    func collectRows(in container: AXElement, sourceWindow: String, registry: KakaoTalkRegistry) throws -> [ChatRowCandidate] {
        let rowElements = try fetchRows(in: container)
        return try rowElements.compactMap { row in
            let texts = try extractTexts(from: row)
            guard let title = texts.first(where: TextNormalizer.likelyHumanReadable) else { return nil }
            let existing = registry.entries().first { $0.title == title && $0.lastMatchedTexts == texts }
            let chatID = existing?.chatID ?? "chat_\(UUID().uuidString.prefix(8))"
            let unreadEstimate = texts.compactMap(Int.init).first
            let metaEstimate = texts.first(where: { $0.range(of: "^[0-9]{1,2}:[0-9]{2}$", options: .regularExpression) != nil })
            return ChatRowCandidate(chatID: chatID, title: title, sourceWindow: sourceWindow, matchableTexts: texts, unreadEstimate: unreadEstimate, metaEstimate: metaEstimate, rowElement: row)
        }
    }

    func openRow(_ row: AXElement) throws {
        if (try? row.actionNames().contains(AXActionNames.press)) == true {
            try AXActions.press(row)
            return
        }
        let descendants = try AXTraversal.collect(root: row, strategy: .breadthFirst, maxDepth: 3, maxNodes: 80)
        if let pressable = descendants.first(where: { (try? $0.element.actionNames().contains(AXActionNames.press)) == true }) {
            try AXActions.press(pressable.element)
            return
        }
        if let frame = try row.frame() {
            try Mouse.doubleClick(centerOf: frame)
            Thread.sleep(forTimeInterval: 0.1)
            try Keyboard.enter()
            return
        }
        try AXActions.focus(row)
        try Keyboard.enter()
    }

    func transcriptRows(in window: AXElement) throws -> [RowSummary] {
        let nodes = try AXTraversal.collect(root: window, strategy: .breadthFirst, maxDepth: 7, maxNodes: 800)
        return try nodes.filter { $0.role == AXRoleNames.row }.prefix(20).map { rowNode in
            try makeRowSummary(from: rowNode)
        }
    }

    private func fetchRows(in container: AXElement) throws -> [AXElement] {
        if let rows = try? container.elementsAttribute(AXAttributeNames.rows), !rows.isEmpty {
            return rows
        }
        if let rows = try? container.elementsAttribute(AXAttributeNames.visibleRows), !rows.isEmpty {
            return rows
        }
        let descendants = try AXTraversal.collect(root: container, strategy: .breadthFirst, maxDepth: 4, maxNodes: 250)
        return descendants.filter { $0.role == AXRoleNames.row }.map(\.element)
    }

    private func extractTexts(from row: AXElement) throws -> [String] {
        let descendants = try AXTraversal.collect(root: row, strategy: .breadthFirst, maxDepth: 4, maxNodes: 150)
        let rawValues = descendants.flatMap { node -> [String] in
            [node.title, node.value, try? node.element.stringAttribute(AXAttributeNames.description)].compactMap { $0 }
        }
        return Array(NSOrderedSet(array: rawValues.filter(TextNormalizer.likelyHumanReadable))) as? [String] ?? []
    }

    private func makeRowSummary(from rowNode: AXTraversalNode) throws -> RowSummary {
        let descendants = try AXTraversal.collect(root: rowNode.element, strategy: .breadthFirst, maxDepth: 4, maxNodes: 150)
        let authorCandidates: [String] = descendants.compactMap { node -> String? in
            guard node.role == AXRoleNames.staticText else { return nil }
            guard let value = node.title ?? node.value, TextNormalizer.likelyHumanReadable(value) else { return nil }
            return value
        }
        let bodyCandidates: [String] = descendants.compactMap { node -> String? in
            guard node.role == AXRoleNames.textArea || node.role == AXRoleNames.staticText else { return nil }
            guard let value = node.value ?? node.title, TextNormalizer.likelyHumanReadable(value) else { return nil }
            return value
        }
        let timeCandidates: [String] = descendants.compactMap { node -> String? in
            guard let value = node.title ?? node.value else { return nil }
            return value.range(of: "^[0-9]{1,2}:[0-9]{2}", options: .regularExpression) != nil ? value : nil
        }
        let buttonTitles: [String] = descendants.compactMap { node -> String? in
            guard node.role == AXRoleNames.button else { return nil }
            return node.title ?? node.value
        }
        return RowSummary(
            authorCandidates: Array(Set(authorCandidates)).sorted(),
            bodyCandidates: Array(Set(bodyCandidates)).sorted(),
            timeCandidates: Array(Set(timeCandidates)).sorted(),
            buttonTitles: Array(Set(buttonTitles)).sorted(),
            path: rowNode.path
        )
    }
}
