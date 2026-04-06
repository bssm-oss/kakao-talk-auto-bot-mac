import AppKit
import Foundation

final class KakaoTalkRecovery {
    private let logger: Logger

    init(logger: Logger) {
        self.logger = logger
    }

    func performRecoverySteps(
        launcher: KakaoTalkLauncher,
        currentApp: NSRunningApplication,
        cache: KakaoTalkCache,
        refreshCache: Bool,
        deepRecovery: Bool
    ) throws {
        logger.recovery("Re-activating KakaoTalk")
        try launcher.activate(currentApp)
        if refreshCache {
            logger.recovery("Refreshing AX cache")
            try cache.reset()
        }
        if deepRecovery {
            logger.recovery("Deep recovery requested: relaunching KakaoTalk")
            currentApp.terminate()
            Thread.sleep(forTimeInterval: 1.0)
            _ = try launcher.prepare(promptForTrust: false)
        }
    }
}
