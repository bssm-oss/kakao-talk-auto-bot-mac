import Foundation
import KTalkAXCore

struct AccessibilityStatusSnapshot: Codable {
    let recordedAt: Date
    let trusted: Bool
    let loginState: String
    let kakaoTalkRunning: Bool
    let activeWindowCount: Int
}

@MainActor
final class AccessibilityStatusRecorder {
    private let fileURL: URL

    init(fileManager: FileManager = .default) {
        let support = (try? fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
            ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support", isDirectory: true)
        let dir = support.appendingPathComponent("katalk-ax", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent("menu-bar-status.json")
    }

    var statusFilePath: String { fileURL.path }

    func record(status: StatusResult) {
        let snapshot = AccessibilityStatusSnapshot(
            recordedAt: Date(),
            trusted: status.permission.trusted,
            loginState: status.loginState,
            kakaoTalkRunning: status.kakaoTalkRunning,
            activeWindowCount: status.activeWindowCount
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(snapshot) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}
