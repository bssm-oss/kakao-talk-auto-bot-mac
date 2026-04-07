import Foundation

public struct CLIArgumentParser {
    private let arguments: [String]

    public init(arguments: [String]) {
        self.arguments = arguments
    }

    public func parse() throws -> CLICommand {
        guard arguments.count >= 2 else {
            throw KTalkAXError.invalidArguments(helpText())
        }

        let commandName = arguments[1]
        let tokens = Array(arguments.dropFirst(2))

        switch commandName {
        case "help", "--help", "-h":
            return .help
        case "status":
            let json = tokens.contains("--json")
            let prompt = tokens.contains("--prompt")
            return .status(StatusCommand(json: json, promptForTrust: prompt))
        case "inspect":
            return .inspect(try parseInspect(tokens: tokens))
        case "chats":
            return .chats(try parseChats(tokens: tokens))
        case "send":
            return .send(try parseSend(tokens: tokens))
        default:
            throw KTalkAXError.invalidArguments("알 수 없는 명령어 '\(commandName)'입니다.\n\n\(helpText())")
        }
    }

    private func parseInspect(tokens: [String]) throws -> InspectCommand {
        var windowIndex: Int?
        var depth = 6
        var showAttributes = false
        var showActions = false
        var showPath = false
        var showFrame = false
        var showIndex = false
        var showFlags = false
        var debugLayout = false
        var rowSummary = false
        var json = false

        var index = 0
        while index < tokens.count {
            let token = tokens[index]
            switch token {
            case "--window":
                index += 1
                windowIndex = try readInt(tokens, index: index, name: "--window")
            case "--depth":
                index += 1
                depth = try readInt(tokens, index: index, name: "--depth")
            case "--show-attributes": showAttributes = true
            case "--show-actions": showActions = true
            case "--show-path": showPath = true
            case "--show-frame": showFrame = true
            case "--show-index": showIndex = true
            case "--show-flags": showFlags = true
            case "--debug-layout": debugLayout = true
            case "--row-summary": rowSummary = true
            case "--json": json = true
            default:
                throw KTalkAXError.invalidArguments("알 수 없는 inspect 옵션 '\(token)'입니다.")
            }
            index += 1
        }

        return InspectCommand(
            windowIndex: windowIndex,
            depth: max(1, depth),
            showAttributes: showAttributes,
            showActions: showActions,
            showPath: showPath,
            showFrame: showFrame,
            showIndex: showIndex,
            showFlags: showFlags,
            debugLayout: debugLayout,
            rowSummary: rowSummary,
            json: json
        )
    }

    private func parseChats(tokens: [String]) throws -> ChatsCommand {
        var limit = 50
        var json = false
        var refreshCache = false
        var noCache = false

        var index = 0
        while index < tokens.count {
            let token = tokens[index]
            switch token {
            case "--limit":
                index += 1
                limit = try readInt(tokens, index: index, name: "--limit")
            case "--json": json = true
            case "--refresh-cache": refreshCache = true
            case "--no-cache": noCache = true
            default:
                throw KTalkAXError.invalidArguments("알 수 없는 chats 옵션 '\(token)'입니다.")
            }
            index += 1
        }

        return ChatsCommand(limit: max(1, limit), json: json, refreshCache: refreshCache, noCache: noCache)
    }

    private func parseSend(tokens: [String]) throws -> SendCommand {
        var chat: String?
        var chatID: String?
        var message: String?
        var dryRun = false
        var confirm = false
        var traceAX = false
        var keepWindow = false
        var deepRecovery = false
        var matchMode = ChatMatchMode.exact
        var speed = SendSpeed.normal
        var json = false
        var refreshCache = false
        var noCache = false

        var index = 0
        while index < tokens.count {
            let token = tokens[index]
            switch token {
            case "--chat":
                index += 1
                chat = try readString(tokens, index: index, name: "--chat")
            case "--chat-id":
                index += 1
                chatID = try readString(tokens, index: index, name: "--chat-id")
            case "--message":
                index += 1
                message = try readString(tokens, index: index, name: "--message")
            case "--dry-run": dryRun = true
            case "--confirm": confirm = true
            case "--trace-ax": traceAX = true
            case "--keep-window": keepWindow = true
            case "--deep-recovery": deepRecovery = true
            case "--match":
                index += 1
                let value = try readString(tokens, index: index, name: "--match")
                guard let parsed = ChatMatchMode(rawValue: value) else {
                    throw KTalkAXError.invalidArguments("잘못된 --match 값 '\(value)'입니다.")
                }
                matchMode = parsed
            case "--speed":
                index += 1
                let value = try readString(tokens, index: index, name: "--speed")
                guard let parsed = SendSpeed(rawValue: value) else {
                    throw KTalkAXError.invalidArguments("잘못된 --speed 값 '\(value)'입니다.")
                }
                speed = parsed
            case "--json": json = true
            case "--refresh-cache": refreshCache = true
            case "--no-cache": noCache = true
            default:
                throw KTalkAXError.invalidArguments("알 수 없는 send 옵션 '\(token)'입니다.")
            }
            index += 1
        }

        if (chat == nil || chat?.isEmpty == true), chatID == nil {
            throw KTalkAXError.invalidArguments("send 명령은 --chat \"<채팅방 이름>\" 또는 --chat-id \"<synthetic id>\"가 필요합니다.")
        }
        guard let message else {
            throw KTalkAXError.invalidArguments("send 명령은 --message \"<메시지>\"가 필요합니다.")
        }

        return SendCommand(
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
            json: json,
            refreshCache: refreshCache,
            noCache: noCache
        )
    }

    private func readString(_ tokens: [String], index: Int, name: String) throws -> String {
        guard tokens.indices.contains(index) else {
            throw KTalkAXError.invalidArguments("\(name)의 값이 없습니다.")
        }
        return tokens[index]
    }

    private func readInt(_ tokens: [String], index: Int, name: String) throws -> Int {
        let value = try readString(tokens, index: index, name: name)
        guard let integer = Int(value) else {
            throw KTalkAXError.invalidArguments("\(name)에는 정수가 필요하지만 '\(value)'가 들어왔습니다.")
        }
        return integer
    }

    public func helpText() -> String {
        """
        katalk-ax - KakaoTalk macOS 접근성 CLI

        명령어:
          status [--json] [--prompt]
          inspect [--window <index>] [--depth <n>] [--show-attributes] [--show-actions] [--show-path] [--show-frame] [--show-index] [--show-flags] [--debug-layout] [--row-summary] [--json]
          chats [--limit <n>] [--json] [--refresh-cache] [--no-cache]
          send [--chat "<name>"] [--chat-id <id>] --message "<text>" [--dry-run] [--confirm] [--trace-ax] [--keep-window] [--deep-recovery] [--match exact|smart|fuzzy] [--speed slow|normal|fast] [--json] [--refresh-cache] [--no-cache]
        """
    }
}
