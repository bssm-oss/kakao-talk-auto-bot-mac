import Foundation

struct AXPathSegment: Codable, Equatable {
    let role: String
    let title: String?
    let index: Int
}

struct StoredAXPath: Codable, Equatable {
    let path: String
    let segments: [AXPathSegment]
    let capturedAt: Date
}

struct AXPathCacheStore: Codable, Equatable {
    var searchField: StoredAXPath?
    var resultList: StoredAXPath?
    var composeField: StoredAXPath?
    var sendButton: StoredAXPath?
}

final class KakaoTalkCache {
    private let fileManager: FileManager
    let cacheURL: URL
    private(set) var store: AXPathCacheStore

    init(fileManager: FileManager) throws {
        self.fileManager = fileManager
        let root = fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".katalk-ax", isDirectory: true)
        if !fileManager.fileExists(atPath: root.path) {
            try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        }
        self.cacheURL = root.appendingPathComponent("ax-cache.json")
        self.store = (try? Self.load(from: cacheURL)) ?? AXPathCacheStore()
    }

    func save() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(store)
        try data.write(to: cacheURL, options: .atomic)
    }

    func reset() throws {
        store = AXPathCacheStore()
        try save()
    }

    func updateSearchField(_ value: StoredAXPath?) throws { store.searchField = value; try save() }
    func updateResultList(_ value: StoredAXPath?) throws { store.resultList = value; try save() }
    func updateComposeField(_ value: StoredAXPath?) throws { store.composeField = value; try save() }
    func updateSendButton(_ value: StoredAXPath?) throws { store.sendButton = value; try save() }

    func resolve(_ storedPath: StoredAXPath?, within root: AXElement) throws -> AXElement? {
        guard let storedPath else { return nil }
        var current = root
        for segment in storedPath.segments {
            let children = try current.children()
            guard children.indices.contains(segment.index) else { return nil }
            let candidate = children[segment.index]
            let role = try candidate.role() ?? ""
            if role != segment.role { return nil }
            if let title = segment.title, !title.isEmpty, try candidate.title() != title {
                return nil
            }
            current = candidate
        }
        return current
    }

    static func capture(node: AXTraversalNode) -> StoredAXPath {
        let segments = node.path.split(separator: "/").dropFirst().compactMap { component -> AXPathSegment? in
            guard let start = component.lastIndex(of: "["), let end = component.lastIndex(of: "]") else { return nil }
            let role = String(component[..<start]).capitalized.withPrefix("AX")
            let index = Int(component[component.index(after: start)..<end]) ?? 0
            return AXPathSegment(role: role, title: nil, index: index)
        }
        return StoredAXPath(path: node.path, segments: segments, capturedAt: Date())
    }

    private static func load(from url: URL) throws -> AXPathCacheStore {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(AXPathCacheStore.self, from: data)
    }
}

private extension String {
    func withPrefix(_ prefix: String) -> String {
        hasPrefix(prefix) ? self : prefix + self
    }
}
