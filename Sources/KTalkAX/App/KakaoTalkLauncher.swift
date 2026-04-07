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
        let trusted = AXIsProcessTrustedWithOptions(options)
        
        if !trusted {
            logger.trace("AXIsProcessTrustedWithOptions returned false (prompt=\(prompt))")
            logger.trace("Current process: \(Bundle.main.bundleIdentifier ?? "nil")")
            logger.trace("Process path: \(Bundle.main.bundlePath)")
        }
        
        return PermissionState(trusted: trusted, promptAttempted: prompt)
    }

    func prepare(promptForTrust: Bool) throws -> AppPreparation {
        let permission = permissionState(prompt: promptForTrust)
        guard permission.trusted else {
            throw KTalkAXError.notTrusted(prompted: promptForTrust)
        }

        let running = try ensureRunningApplication()
        let element = AXElement.appElement(pid: running.processIdentifier)
        try activate(running)
        if (try? waitForWindowReadiness(element: element)) == nil {
            logger.trace("Window readiness timed out; retrying with unhide and open fallback")
            _ = running.unhide()
            let fallback = Process()
            fallback.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            fallback.arguments = ["-a", "KakaoTalk"]
            try fallback.run()
            fallback.waitUntilExit()
            try activate(running)
            try waitForWindowReadiness(element: element)
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
            throw KTalkAXError.kakaoTalkNotAvailable("KakaoTalk.app이 설치되어 있지 않거나 /Applications에서 찾을 수 없습니다.")
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
            throw KTalkAXError.kakaoTalkNotAvailable("KakaoTalk.app 실행에 실패했습니다: \(launchError.localizedDescription)")
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
        var windows = try appElement.windows()
        if windows.isEmpty, let focusedWindow = try appElement.focusedWindow() {
            windows = [focusedWindow]
        }
        if windows.isEmpty {
            throw KTalkAXError.loginRequired("KakaoTalk 창을 찾지 못했습니다. 로그인되어 있고 잠금이 해제되어 있는지 확인하세요.")
        }
        let hints = try windows.prefix(3).flatMap { window in
            try AXTraversal.collect(root: window, strategy: .breadthFirst, maxDepth: 3, maxNodes: 120).compactMap { $0.title ?? $0.value }
        }
        if hints.contains(where: { $0.localizedCaseInsensitiveContains("login") || $0.contains("로그인") }) {
            throw KTalkAXError.loginRequired("KakaoTalk이 로그인 화면에 있는 것 같습니다. 먼저 로그인하세요.")
        }
        if hints.contains(where: { $0.localizedCaseInsensitiveContains("lock") || $0.contains("잠금") }) {
            throw KTalkAXError.locked("KakaoTalk이 잠긴 상태인 것 같습니다. katalk-ax를 사용하기 전에 잠금을 해제하세요.")
        }
    }

    private func waitForWindowReadiness(element: AXElement) throws {
        _ = try Timeout.poll(label: "KakaoTalk window readiness", timeout: 10.0, interval: 0.4) {
            let windows = try? element.windows()
            if windows?.isEmpty == false {
                return true
            }
            let focusedWindow = try? element.focusedWindow()
            return focusedWindow == nil ? nil : true
        }
    }
}

private final class LaunchResultBox: @unchecked Sendable {
    var error: Error?
}
