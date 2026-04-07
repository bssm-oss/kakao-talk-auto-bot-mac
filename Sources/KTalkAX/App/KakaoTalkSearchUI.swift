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
        let bestNode = candidates.first ?? recursiveSearchField(from: window, depth: 0)
        guard let best = bestNode else {
            throw KTalkAXError.invalidUI("검색 입력창을 찾지 못했습니다. 현재 AX 트리를 확인하려면 inspect를 실행하세요.")
        }
        return (best.element, StoredAXPath(path: best.path, segments: KakaoTalkCache.capture(node: best).segments, capturedAt: Date()))
    }

    private func recursiveSearchField(from element: AXElement, depth: Int) -> AXTraversalNode? {
        if depth > 6 { return nil }
        let role = (try? element.role()) ?? ""
        let subrole = (try? element.subrole()) ?? ""
        if role == AXRoleNames.textField || role == AXRoleNames.textArea || subrole == "AXSearchField" {
            return AXTraversalNode(
                element: element,
                depth: depth,
                path: "recursive-search-field",
                siblingIndex: 0,
                frame: try? element.frame(),
                role: try? element.role(),
                subrole: try? element.subrole(),
                title: try? element.title(),
                value: try? element.valueAsString()
            )
        }
        let children = (try? element.children()) ?? []
        for child in children {
            if let found = recursiveSearchField(from: child, depth: depth + 1) {
                return found
            }
        }
        return nil
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
        if let directTable = try directResultsContainer(in: window) {
            return (directTable, nil)
        }
        let nodes = try AXTraversal.collect(root: window, strategy: .breadthFirst, maxDepth: 6, maxNodes: 500)
        let candidates = nodes.filter { node in
            [AXRoleNames.table, AXRoleNames.outline, AXRoleNames.list, AXRoleNames.scrollArea, AXRoleNames.group].contains(node.role ?? "")
        }
        let bestNode = try candidates.first(where: { node in
            if let rows = try? node.element.elementsAttribute(AXAttributeNames.rows), !rows.isEmpty {
                return true
            }
            if let rows = try? node.element.elementsAttribute(AXAttributeNames.visibleRows), !rows.isEmpty {
                return true
            }
            let descendants = try AXTraversal.collect(root: node.element, strategy: .breadthFirst, maxDepth: 3, maxNodes: 200)
            return descendants.contains(where: { $0.role == AXRoleNames.row })
        })
        let bestElement = bestNode?.element ?? recursiveResultsContainer(from: window, depth: 0)
        guard let bestElement else {
            throw KTalkAXError.invalidUI("검색 결과 목록을 찾지 못했습니다. 더 자세한 구조를 보려면 --debug-layout과 함께 inspect를 실행하세요.")
        }
        if let bestNode {
            return (bestNode.element, StoredAXPath(path: bestNode.path, segments: KakaoTalkCache.capture(node: bestNode).segments, capturedAt: Date()))
        }
        return (bestElement, nil)
    }

    private func directResultsContainer(in window: AXElement) throws -> AXElement? {
        let children = try window.children()
        if let scrollArea = children.first(where: { (try? $0.role()) == AXRoleNames.scrollArea }),
           let table = try scrollArea.children().first(where: {
               let role = (try? $0.role()) ?? ""
               guard [AXRoleNames.table, AXRoleNames.outline, AXRoleNames.list].contains(role) else { return false }
               if let rows = try? $0.elementsAttribute(AXAttributeNames.rows), !rows.isEmpty { return true }
               if let rows = try? $0.elementsAttribute(AXAttributeNames.visibleRows), !rows.isEmpty { return true }
               return false
           }) {
            return table
        }
        return nil
    }

    private func recursiveResultsContainer(from element: AXElement, depth: Int) -> AXElement? {
        if depth > 8 { return nil }
        let role = (try? element.role()) ?? ""
        if [AXRoleNames.table, AXRoleNames.outline, AXRoleNames.list, AXRoleNames.scrollArea, AXRoleNames.group].contains(role) {
            if let rows = try? element.elementsAttribute(AXAttributeNames.rows), !rows.isEmpty {
                return element
            }
            if let rows = try? element.elementsAttribute(AXAttributeNames.visibleRows), !rows.isEmpty {
                return element
            }
        }

        let children = (try? element.children()) ?? []
        if [AXRoleNames.scrollArea, AXRoleNames.group].contains(role),
           let nestedTable = children.first(where: {
               let childRole = (try? $0.role()) ?? ""
               guard [AXRoleNames.table, AXRoleNames.outline, AXRoleNames.list].contains(childRole) else { return false }
               if let rows = try? $0.elementsAttribute(AXAttributeNames.rows), !rows.isEmpty { return true }
               if let rows = try? $0.elementsAttribute(AXAttributeNames.visibleRows), !rows.isEmpty { return true }
               return false
           }) {
            return nestedTable
        }

        for child in children {
            if let found = recursiveResultsContainer(from: child, depth: depth + 1) {
                return found
            }
        }
        return nil
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

    func openVisibleRow(named title: String, in window: AXElement) throws {
        if let row = try findDirectTableRow(named: title, in: window) ?? findVisibleRow(named: title, in: window) {
            if let frame = try row.frame() {
                try Mouse.doubleClick(centerOf: frame)
                Thread.sleep(forTimeInterval: 0.15)
                try Keyboard.enter()
                return
            }
            try AXActions.focus(row)
            try Keyboard.enter()
            return
        }
        throw KTalkAXError.chatNotFound("현재 보이는 목록에서 '\(title)' 채팅 행을 찾지 못했습니다.")
    }

    private func findDirectTableRow(named title: String, in window: AXElement) throws -> AXElement? {
        let normalizedExpected = TextNormalizer.normalize(title)
        let scrollArea = try window.children().first(where: { (try? $0.role()) == AXRoleNames.scrollArea })
        let table = try scrollArea?.children().first(where: { (try? $0.role()) == AXRoleNames.table || (try? $0.role()) == AXRoleNames.outline || (try? $0.role()) == AXRoleNames.list })
        let rows = (try? table?.elementsAttribute(AXAttributeNames.rows)) ?? []
        for row in rows {
            let texts = try directTexts(from: row)
            if texts.contains(where: { TextNormalizer.normalize($0) == normalizedExpected }) {
                return row
            }
        }
        return nil
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

    private func findVisibleRow(named title: String, in window: AXElement) throws -> AXElement? {
        let normalizedExpected = TextNormalizer.normalize(title)
        let strippedExpected = TextNormalizer.normalize(title, stripSeparators: true)
        let nodes = try AXTraversal.collect(root: window, strategy: .breadthFirst, maxDepth: 6, maxNodes: 500)
        let containers = nodes.filter { [AXRoleNames.table, AXRoleNames.outline, AXRoleNames.list, AXRoleNames.scrollArea, AXRoleNames.group].contains($0.role ?? "") }
        for container in containers {
            let rows = (try? fetchRows(in: container.element)) ?? []
            if let match = try rows.first(where: { row in
                let texts = try extractTexts(from: row)
                return texts.contains { text in
                    let normalized = TextNormalizer.normalize(text)
                    let stripped = TextNormalizer.normalize(text, stripSeparators: true)
                    return normalized == normalizedExpected || stripped == strippedExpected
                }
            }) {
                return match
            }
        }
        return nil
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

    private func directTexts(from element: AXElement, depth: Int = 0) throws -> [String] {
        if depth > 3 { return [] }
        var texts: [String] = []
        if let title = try? element.title(), !title.isEmpty {
            texts.append(title)
        }
        if let value = try? element.valueAsString(), !value.isEmpty {
            texts.append(value)
        }
        for child in try element.children() {
            texts.append(contentsOf: try directTexts(from: child, depth: depth + 1))
        }
        return texts
    }
}
