import Foundation

struct AXNodeInspection: Codable {
    let role: String?
    let title: String?
    let value: String?
    let description: String?
    let subrole: String?
    let frame: RectSnapshot?
    let path: String?
    let siblingIndex: Int?
    let flags: NodeFlags?
    let actions: [String]?
    let attributeNames: [String]?
}

struct RowSummary: Codable {
    let authorCandidates: [String]
    let bodyCandidates: [String]
    let timeCandidates: [String]
    let buttonTitles: [String]
    let path: String
}

enum AXInspector {
    static func dump(
        window: AXElement,
        options: InspectCommand
    ) throws -> ([AXNodeInspection], [RowSummary]) {
        let nodes = try AXTraversal.collect(root: window, strategy: .breadthFirst, maxDepth: options.depth)
        let inspections = nodes.map { node in
            AXNodeInspection(
                role: node.role,
                title: node.title,
                value: node.value,
                description: try? node.element.stringAttribute(AXAttributeNames.description),
                subrole: node.subrole,
                frame: options.showFrame ? RectSnapshot(node.frame) : nil,
                path: options.showPath ? node.path : nil,
                siblingIndex: options.showIndex ? node.siblingIndex : nil,
                flags: options.showFlags ? NodeFlags(element: node.element) : nil,
                actions: options.showActions ? (try? node.element.actionNames()) : nil,
                attributeNames: options.showAttributes ? (try? node.element.attributeNames()) : nil
            )
        }

        let rows: [RowSummary]
        if options.rowSummary {
            rows = try nodes
                .filter { $0.role == AXRoleNames.row }
                .map { try summarize(rowNode: $0) }
        } else {
            rows = []
        }

        return (inspections, rows)
    }

    static func renderText(nodes: [AXNodeInspection], rows: [RowSummary]) -> String {
        var lines = nodes.map { node -> String in
            var parts: [String] = []
            parts.append(node.role ?? "unknown")
            if let title = node.title, !title.isEmpty { parts.append("title=\"\(title)\"") }
            if let value = node.value, !value.isEmpty { parts.append("value=\"\(value)\"") }
            if let description = node.description, !description.isEmpty { parts.append("description=\"\(description)\"") }
            if let subrole = node.subrole, !subrole.isEmpty { parts.append("subrole=\(subrole)") }
            if let frame = node.frame { parts.append("frame=\(frame.text)") }
            if let path = node.path { parts.append("path=\(path)") }
            if let siblingIndex = node.siblingIndex { parts.append("index=\(siblingIndex)") }
            if let flags = node.flags { parts.append("flags=\(flags.text)") }
            if let actions = node.actions, !actions.isEmpty { parts.append("actions=\(actions.joined(separator: ","))") }
            if let attributes = node.attributeNames, !attributes.isEmpty { parts.append("attributes=\(attributes.joined(separator: ","))") }
            return parts.joined(separator: " ")
        }
        if !rows.isEmpty {
            lines.append("-- row summary --")
            for row in rows {
                lines.append("path=\(row.path) author=\(row.authorCandidates) body=\(row.bodyCandidates) time=\(row.timeCandidates) buttons=\(row.buttonTitles)")
            }
        }
        return lines.joined(separator: "\n")
    }

    private static func summarize(rowNode: AXTraversalNode) throws -> RowSummary {
        let descendants = try AXTraversal.collect(root: rowNode.element, strategy: .breadthFirst, maxDepth: 4)
        let authorCandidates: [String] = descendants.compactMap { node -> String? in
            guard node.role == AXRoleNames.staticText else { return nil }
            guard let title = node.title ?? node.value, TextNormalizer.likelyHumanReadable(title) else { return nil }
            return title
        }
        let bodyCandidates: [String] = descendants.compactMap { node -> String? in
            guard node.role == AXRoleNames.textArea || node.role == AXRoleNames.staticText else { return nil }
            guard let value = node.value ?? node.title, TextNormalizer.likelyHumanReadable(value) else { return nil }
            return value
        }
        let timeCandidates: [String] = descendants.compactMap { node -> String? in
            guard let text = node.title ?? node.value else { return nil }
            return text.range(of: "^[0-9]{1,2}:[0-9]{2}", options: .regularExpression) != nil ? text : nil
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

struct RectSnapshot: Codable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double

    init?(_ rect: CGRect?) {
        guard let rect else { return nil }
        x = rect.origin.x
        y = rect.origin.y
        width = rect.size.width
        height = rect.size.height
    }

    var text: String { "(x: \(Int(x)), y: \(Int(y)), w: \(Int(width)), h: \(Int(height)))" }
}

struct NodeFlags: Codable {
    let enabled: Bool?
    let focused: Bool?
    let selected: Bool?
    let editable: Bool?

    init(element: AXElement) {
        enabled = try? element.boolAttribute(AXAttributeNames.enabled)
        focused = try? element.boolAttribute(AXAttributeNames.focused)
        selected = try? element.boolAttribute(AXAttributeNames.selected)
        editable = try? element.isAttributeSettable(AXAttributeNames.value)
    }

    var text: String {
        "enabled=\(enabled?.description ?? "nil"),focused=\(focused?.description ?? "nil"),selected=\(selected?.description ?? "nil"),editable=\(editable?.description ?? "nil")"
    }
}
