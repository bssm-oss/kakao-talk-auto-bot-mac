import AppKit
import ApplicationServices
import Foundation

public struct PermissionState: Codable {
    public let trusted: Bool
    public let promptAttempted: Bool
}

struct AppPreparation {
    let app: NSRunningApplication
    let appElement: AXElement
    let permission: PermissionState
}

final class KakaoTalkLauncher {
    private let trustedPromptKey = "AXTrustedCheckOptionPrompt"
    private let locator: KakaoTalkLocator
    private let logger: Logger

    init(locator: KakaoTalkLocator, logger: Logger) {
        self.locator = locator
        self.logger = logger
    }

    func permissionState(prompt: Bool) -> PermissionState {
        let options = [trustedPromptKey: prompt] as CFDictionary
        return PermissionState(trusted: AXIsProcessTrustedWithOptions(options), promptAttempted: prompt)
    }

    func prepare(promptForTrust: Bool) throws -> AppPreparation {
        let permission = permissionState(prompt: promptForTrust)
        guard permission.trusted else {
            throw KTalkAXError.notTrusted(prompted: promptForTrust)
        }

        let running = try ensureRunningApplication()
        let element = AXElement.appElement(pid: running.processIdentifier)
        try activate(running)
        _ = try Timeout.poll(label: "KakaoTalk window readiness", timeout: 10.0, interval: 0.4) {
            let windows = try? element.windows()
            return (windows?.isEmpty == false) ? true : nil
        }
        try assertLikelyLoggedIn(appElement: element)
        return AppPreparation(app: running, appElement: element, permission: permission)
    }

    func activate(_ app: NSRunningApplication) throws {
        logger.trace("Activating KakaoTalk pid=\(app.processIdentifier)")
        _ = app.activate(options: [.activateAllWindows])
        Thread.sleep(forTimeInterval: 0.2)
    }

    private func ensureRunningApplication() throws -> NSRunningApplication {
        if let running = locator.locateRunningApp()?.runningApplication {
            return running
        }
        guard let appURL = locator.installedAppURL() else {
            throw KTalkAXError.kakaoTalkNotAvailable("KakaoTalk.app is not installed or was not found in /Applications.")
        }
        logger.info("Launching KakaoTalk from \(appURL.path)")
        let semaphore = DispatchSemaphore(value: 0)
        let launchResult = LaunchResultBox()
        let configuration = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.openApplication(at: appURL, configuration: configuration) { _, error in
            launchResult.error = error
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .now() + 15)
        if let launchError = launchResult.error {
            throw KTalkAXError.kakaoTalkNotAvailable("Failed to launch KakaoTalk.app: \(launchError.localizedDescription)")
        }
        if let running = try? Timeout.poll(label: "KakaoTalk process", timeout: 15.0, interval: 0.5, operation: {
            locator.locateRunningApp()?.runningApplication
        }) {
            return running
        }

        let fallback = Process()
        fallback.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        fallback.arguments = ["-a", "KakaoTalk"]
        try fallback.run()
        fallback.waitUntilExit()

        return try Timeout.poll(label: "KakaoTalk process after fallback launch", timeout: 20.0, interval: 0.5) {
            locator.locateRunningApp()?.runningApplication
        }
    }

    private func assertLikelyLoggedIn(appElement: AXElement) throws {
        let windows = try appElement.windows()
        if windows.isEmpty {
            throw KTalkAXError.loginRequired("KakaoTalk did not expose any windows. Verify that it is logged in and unlocked.")
        }
        let hints = try windows.prefix(3).flatMap { window in
            try AXTraversal.collect(root: window, strategy: .breadthFirst, maxDepth: 3, maxNodes: 120).compactMap { $0.title ?? $0.value }
        }
        if hints.contains(where: { $0.localizedCaseInsensitiveContains("login") || $0.contains("로그인") }) {
            throw KTalkAXError.loginRequired("KakaoTalk appears to be on a login screen. Log in first.")
        }
        if hints.contains(where: { $0.localizedCaseInsensitiveContains("lock") || $0.contains("잠금") }) {
            throw KTalkAXError.locked("KakaoTalk appears to be locked. Unlock it before using katalk-ax.")
        }
    }
}

private final class LaunchResultBox: @unchecked Sendable {
    var error: Error?
}
