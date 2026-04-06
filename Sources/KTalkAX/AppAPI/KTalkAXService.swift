import Foundation

public final class KTalkAXService {
    public init() {}

    public func status(promptForTrust: Bool = false) throws -> StatusResult {
        try makeSender(logger: Logger(traceAX: false)).status(promptForTrust: promptForTrust)
    }

    public func chats(limit: Int = 50, refreshCache: Bool = false, noCache: Bool = false) throws -> ChatsResult {
        try makeSender(logger: Logger(traceAX: false)).chats(options: ChatsCommand(limit: max(1, limit), json: false, refreshCache: refreshCache, noCache: noCache))
    }

    public func inspectText(windowIndex: Int? = nil, depth: Int = 4) throws -> String {
        try makeSender(logger: Logger(traceAX: false)).inspect(options: InspectCommand(
            windowIndex: windowIndex,
            depth: max(1, depth),
            showAttributes: false,
            showActions: false,
            showPath: true,
            showFrame: false,
            showIndex: false,
            showFlags: false,
            debugLayout: false,
            rowSummary: false,
            json: false
        )).textDescription
    }

    public func send(
        chat: String? = nil,
        chatID: String? = nil,
        message: String,
        dryRun: Bool = false,
        confirm: Bool = false,
        traceAX: Bool = false,
        keepWindow: Bool = false,
        deepRecovery: Bool = false,
        matchMode: ChatMatchMode = .exact,
        speed: SendSpeed = .normal,
        refreshCache: Bool = false,
        noCache: Bool = false
    ) throws -> SendResult {
        let logger = Logger(traceAX: traceAX)
        return try makeSender(logger: logger).send(options: SendCommand(
            chat: chat,
            chatID: chatID,
            message: message,
            dryRun: dryRun,
            confirm: confirm,
            traceAX: traceAX,
            keepWindow: keepWindow,
            deepRecovery: deepRecovery,
            matchMode: matchMode,
            speed: speed,
            json: false,
            refreshCache: refreshCache,
            noCache: noCache
        ))
    }

    private func makeSender(logger: Logger) throws -> KakaoTalkSender {
        let fileManager = FileManager.default
        let cache = try KakaoTalkCache(fileManager: fileManager)
        let registry = try KakaoTalkRegistry(fileManager: fileManager)
        let locator = KakaoTalkLocator()
        let launcher = KakaoTalkLauncher(locator: locator, logger: logger)
        let windows = KakaoTalkWindows(logger: logger)
        let searchUI = KakaoTalkSearchUI(logger: logger)
        let composer = KakaoTalkComposer(logger: logger)
        let recovery = KakaoTalkRecovery(logger: logger)
        let matcher = KakaoTalkChatMatcher(logger: logger)
        return KakaoTalkSender(
            logger: logger,
            cache: cache,
            registry: registry,
            locator: locator,
            launcher: launcher,
            windows: windows,
            searchUI: searchUI,
            composer: composer,
            recovery: recovery,
            matcher: matcher
        )
    }
}
