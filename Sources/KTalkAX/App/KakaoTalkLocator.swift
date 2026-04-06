import AppKit
import Foundation

struct LocatedKakaoTalkApp {
    let runningApplication: NSRunningApplication
    let bundleIdentifierMatch: Bool
}

struct KakaoTalkLocator {
    private let preferredBundleIdentifiers = [
        "com.kakao.KakaoTalkMac",
        "com.kakao.talk",
        "com.kakao.KakaoTalk"
    ]

    func locateRunningApp() -> LocatedKakaoTalkApp? {
        for identifier in preferredBundleIdentifiers {
            if let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == identifier }) {
                return LocatedKakaoTalkApp(runningApplication: app, bundleIdentifierMatch: true)
            }
        }
        if let app = NSWorkspace.shared.runningApplications.first(where: { $0.localizedName == "KakaoTalk" }) {
            return LocatedKakaoTalkApp(runningApplication: app, bundleIdentifierMatch: false)
        }
        return nil
    }

    func installedAppURL() -> URL? {
        let applications = [
            URL(fileURLWithPath: "/Applications/KakaoTalk.app"),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications/KakaoTalk.app")
        ]
        return applications.first(where: { FileManager.default.fileExists(atPath: $0.path) })
    }
}
