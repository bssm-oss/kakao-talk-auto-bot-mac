import Foundation

struct ChatRegistryEntry: Codable, Equatable {
    let chatID: String
    var title: String
    var normalizedTitle: String
    var firstSeenAt: Date
    var lastSeenAt: Date
    var lastMatchedTexts: [String]
}

struct ChatRegistryStore: Codable, Equatable {
    var entries: [ChatRegistryEntry]
}

final class KakaoTalkRegistry {
    private let fileManager: FileManager
    let registryURL: URL
    private(set) var store: ChatRegistryStore

    init(fileManager: FileManager) throws {
        self.fileManager = fileManager
        let root = fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".katalk-ax", isDirectory: true)
        if !fileManager.fileExists(atPath: root.path) {
            try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        }
        registryURL = root.appendingPathComponent("chat-registry.json")
        store = (try? Self.load(from: registryURL)) ?? ChatRegistryStore(entries: [])
    }

    func save() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(store)
        try data.write(to: registryURL, options: .atomic)
    }

    func upsert(title: String, matchableTexts: [String], preferredChatID: String? = nil) throws -> ChatRegistryEntry {
        let normalized = TextNormalizer.normalize(title)
        let now = Date()
        if let preferredChatID, let index = store.entries.firstIndex(where: { $0.chatID == preferredChatID }) {
            store.entries[index].title = title
            store.entries[index].normalizedTitle = normalized
            store.entries[index].lastSeenAt = now
            store.entries[index].lastMatchedTexts = matchableTexts
            try save()
            return store.entries[index]
        }
        if let index = store.entries.firstIndex(where: { $0.title == title && $0.lastMatchedTexts == matchableTexts }) {
            store.entries[index].lastSeenAt = now
            try save()
            return store.entries[index]
        }
        let entry = ChatRegistryEntry(
            chatID: preferredChatID ?? "chat_\(UUID().uuidString.prefix(8))",
            title: title,
            normalizedTitle: normalized,
            firstSeenAt: now,
            lastSeenAt: now,
            lastMatchedTexts: matchableTexts
        )
        store.entries.append(entry)
        try save()
        return entry
    }

    func find(byChatID chatID: String?) -> ChatRegistryEntry? {
        guard let chatID else { return nil }
        return store.entries.first(where: { $0.chatID == chatID })
    }

    func entries() -> [ChatRegistryEntry] { store.entries }

    private static func load(from url: URL) throws -> ChatRegistryStore {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ChatRegistryStore.self, from: data)
    }
}
