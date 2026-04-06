import Foundation

public enum CLICommand {
    case help
    case status(StatusCommand)
    case inspect(InspectCommand)
    case chats(ChatsCommand)
    case send(SendCommand)
}

public struct StatusCommand {
    let json: Bool
    let promptForTrust: Bool
}

public struct InspectCommand {
    let windowIndex: Int?
    let depth: Int
    let showAttributes: Bool
    let showActions: Bool
    let showPath: Bool
    let showFrame: Bool
    let showIndex: Bool
    let showFlags: Bool
    let debugLayout: Bool
    let rowSummary: Bool
    let json: Bool
}

public struct ChatsCommand {
    let limit: Int
    let json: Bool
    let refreshCache: Bool
    let noCache: Bool
}

public enum SendSpeed: String, Codable {
    case slow
    case normal
    case fast

    var delayMultiplier: Double {
        switch self {
        case .slow: return 2.2
        case .normal: return 1.0
        case .fast: return 0.65
        }
    }
}

public struct SendCommand {
    let chat: String?
    let chatID: String?
    let message: String
    let dryRun: Bool
    let confirm: Bool
    let traceAX: Bool
    let keepWindow: Bool
    let deepRecovery: Bool
    let matchMode: ChatMatchMode
    let speed: SendSpeed
    let json: Bool
    let refreshCache: Bool
    let noCache: Bool
}

public struct KTalkAXApplication {
    let command: CLICommand

    public init(command: CLICommand) {
        self.command = command
    }

    public func run() throws -> ExitCode {
        switch command {
        case .help:
            print(CLIArgumentParser(arguments: CommandLine.arguments).helpText())
            return .success
        case .status(let options):
            let logger = Logger(traceAX: false)
            let sender = try makeSender(logger: logger)
            let result = try sender.status(promptForTrust: options.promptForTrust)
            try ResultPrinter(outputJSON: options.json).printResult(result, text: result.textDescription)
            return result.permission.trusted ? .success : .accessibilityPermissionDenied
        case .inspect(let options):
            let logger = Logger(traceAX: options.debugLayout)
            let sender = try makeSender(logger: logger)
            let result = try sender.inspect(options: options)
            try ResultPrinter(outputJSON: options.json).printResult(result, text: result.textDescription)
            return .success
        case .chats(let options):
            let logger = Logger(traceAX: false)
            let sender = try makeSender(logger: logger)
            let result = try sender.chats(options: options)
            try ResultPrinter(outputJSON: options.json).printResult(result, text: result.textDescription)
            return .success
        case .send(let options):
            let logger = Logger(traceAX: options.traceAX)
            let sender = try makeSender(logger: logger)
            let result = try sender.send(options: options)
            try ResultPrinter(outputJSON: options.json).printResult(result, text: result.textDescription)
            return .success
        }
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
