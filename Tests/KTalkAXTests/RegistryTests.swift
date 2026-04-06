import Foundation
import Testing
@testable import KTalkAXCore

struct RegistryTests {
    @Test func registryReadWrite() throws {
        let temp = try makeTempHome()
        let fileManager = FileManager.default
        defer { try? fileManager.removeItem(at: temp) }
        let original = fileManager.homeDirectoryForCurrentUser
        setenv("HOME", temp.path, 1)
        defer { setenv("HOME", original.path, 1) }

        let registry = try KakaoTalkRegistry(fileManager: fileManager)
        let entry = try registry.upsert(title: "홍길동", matchableTexts: ["홍길동"])
        #expect(entry.normalizedTitle == "홍길동")

        let reloaded = try KakaoTalkRegistry(fileManager: fileManager)
        #expect(reloaded.entries().count == 1)
        #expect(reloaded.entries().first?.title == "홍길동")
    }

    @Test func cacheReadWrite() throws {
        let temp = try makeTempHome()
        let fileManager = FileManager.default
        defer { try? fileManager.removeItem(at: temp) }
        let original = fileManager.homeDirectoryForCurrentUser
        setenv("HOME", temp.path, 1)
        defer { setenv("HOME", original.path, 1) }

        let cache = try KakaoTalkCache(fileManager: fileManager)
        try cache.updateSearchField(StoredAXPath(path: "window[0]/textField[0]", segments: [AXPathSegment(role: AXRoleNames.textField, title: nil, index: 0)], capturedAt: Date()))
        let reloaded = try KakaoTalkCache(fileManager: fileManager)
        #expect(reloaded.store.searchField?.path == "window[0]/textField[0]")
    }

    @Test func sendResultJSONEncoding() throws {
        let result = SendResult(
            ok: true,
            command: "send",
            requestedChat: "홍길동",
            matchedChat: "홍길동",
            matchMode: .exact,
            matchScore: 100,
            messageLength: 5,
            dryRun: false,
            sent: true,
            verified: true,
            usedFallback: ["pasteboard"],
            timingsMS: SendTimings(launch: 1, search: 2, open: 3, compose: 4, send: 5, verify: 6),
            textDescription: "ok"
        )
        let data = try JSONEncoder().encode(result)
        let json = String(decoding: data, as: UTF8.self)
        #expect(json.contains("requested_chat"))
        #expect(json.contains("timings_ms"))
    }

    private func makeTempHome() throws -> URL {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        return temp
    }
}
