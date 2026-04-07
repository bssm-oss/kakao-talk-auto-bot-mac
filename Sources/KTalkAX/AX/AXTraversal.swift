import CoreGraphics
import Foundation

enum TraversalStrategy {
    case depthFirst
    case breadthFirst
}

struct AXTraversalFilter {
    var roles: Set<String> = []
    var titleContains: String?
    var valueContains: String?
    var subroles: Set<String> = []

    func matches(_ node: AXTraversalNode) -> Bool {
        if !roles.isEmpty && !roles.contains(node.role ?? "") { return false }
        if let titleContains, !(node.title ?? "").localizedCaseInsensitiveContains(titleContains) { return false }
        if let valueContains, !(node.value ?? "").localizedCaseInsensitiveContains(valueContains) { return false }
        if !subroles.isEmpty && !subroles.contains(node.subrole ?? "") { return false }
        return true
    }
}

struct AXTraversalNode {
    let element: AXElement
    let depth: Int
    let path: String
    let siblingIndex: Int
    let frame: CGRect?
    let role: String?
    let subrole: String?
    let title: String?
    let value: String?
}

enum AXTraversal {
    static func collect(
        root: AXElement,
        strategy: TraversalStrategy,
        maxDepth: Int,
        maxNodes: Int = 1500,
        timeout: TimeInterval = 3.0,
        filter: AXTraversalFilter? = nil
    ) throws -> [AXTraversalNode] {
        let deadline = Date().addingTimeInterval(timeout)
        var results: [AXTraversalNode] = []
        var frontier: [(element: AXElement, depth: Int, siblingIndex: Int, path: String)] = [(root, 0, 0, "root[0]")]

        while !frontier.isEmpty {
            if Date() > deadline {
                throw KTalkAXError.timeout("접근성 트리를 순회하는 중 시간이 초과되었습니다.")
            }
            if results.count >= maxNodes { break }

            let next: (element: AXElement, depth: Int, siblingIndex: Int, path: String)
            switch strategy {
            case .depthFirst: next = frontier.removeLast()
            case .breadthFirst: next = frontier.removeFirst()
            }

            let node = AXTraversalNode(
                element: next.element,
                depth: next.depth,
                path: next.path,
                siblingIndex: next.siblingIndex,
                frame: try? next.element.frame(),
                role: try? next.element.role(),
                subrole: try? next.element.subrole(),
                title: try? next.element.title(),
                value: try? next.element.valueAsString()
            )

            if filter?.matches(node) ?? true {
                results.append(node)
            }

            if next.depth >= maxDepth { continue }

            let children = (try? next.element.children()) ?? []
            for (index, child) in children.enumerated() {
                let role = ((try? child.role()) ?? "unknown").replacingOccurrences(of: "AX", with: "").lowercased()
                let path = next.path + "/\(role)[\(index)]"
                frontier.append((child, next.depth + 1, index, path))
            }
        }

        return results
    }

    static func lazySequence(
        root: AXElement,
        strategy: TraversalStrategy,
        maxDepth: Int,
        maxNodes: Int = 1500,
        timeout: TimeInterval = 3.0
    ) -> AnySequence<AXTraversalNode> {
        AnySequence {
            var index = 0
            let nodes = (try? collect(root: root, strategy: strategy, maxDepth: maxDepth, maxNodes: maxNodes, timeout: timeout)) ?? []
            return AnyIterator<AXTraversalNode> {
                guard index < nodes.count else { return nil }
                defer { index += 1 }
                return nodes[index]
            }
        }
    }
}
