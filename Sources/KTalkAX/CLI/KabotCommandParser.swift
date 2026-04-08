import Foundation

public struct KabotCommand: Equatable {
    public let room: String
    public let message: String
    public let dryRun: Bool
    public let json: Bool
    public let traceAX: Bool

    public init(room: String, message: String, dryRun: Bool, json: Bool, traceAX: Bool) {
        self.room = room
        self.message = message
        self.dryRun = dryRun
        self.json = json
        self.traceAX = traceAX
    }
}

public struct KabotCommandParser {
    public init() {}

    public func parse(arguments: [String]) throws -> KabotCommand? {
        let normalized = arguments.map(normalizeDash)
        let tokens = Array(normalized.dropFirst())

        if tokens.isEmpty || tokens.contains("--help") || tokens.contains("-h") {
            return nil
        }

        var room: String?
        var message: String?
        var dryRun = false
        var json = false
        var traceAX = false

        var index = 0
        while index < tokens.count {
            let token = tokens[index]
            switch token {
            case "--room", "--rome":
                index += 1
                guard tokens.indices.contains(index) else {
                    throw KTalkAXError.invalidArguments("kabot 명령은 --room \"<채팅방 이름>\" 값이 필요합니다.")
                }
                room = tokens[index]
            case "--message":
                index += 1
                guard tokens.indices.contains(index) else {
                    throw KTalkAXError.invalidArguments("kabot 명령은 --message \"<메시지>\" 값이 필요합니다.")
                }
                message = tokens[index]
            case "--dry-run":
                dryRun = true
            case "--json":
                json = true
            case "--trace-ax":
                traceAX = true
            default:
                throw KTalkAXError.invalidArguments("알 수 없는 kabot 옵션 '\(token)'입니다.\n\n\(helpText())")
            }
            index += 1
        }

        guard let room, !room.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw KTalkAXError.invalidArguments("kabot 명령은 --room \"<채팅방 이름>\"이 필요합니다.\n\n\(helpText())")
        }
        guard let message else {
            throw KTalkAXError.invalidArguments("kabot 명령은 --message \"<메시지>\"가 필요합니다.\n\n\(helpText())")
        }

        return KabotCommand(
            room: room,
            message: message,
            dryRun: dryRun,
            json: json,
            traceAX: traceAX
        )
    }

    public func helpText() -> String {
        """
        kabot - 간단 전송 CLI

        사용법:
          kabot --room "<채팅방 이름>" --message "<메시지>" [--dry-run] [--json] [--trace-ax]

        예시:
          kabot --room "허동운" --message "안녕"
          kabot --rome "허동운" --message "안녕" --dry-run
        """
    }

    private func normalizeDash(_ token: String) -> String {
        token
            .replacingOccurrences(of: "—", with: "--")
            .replacingOccurrences(of: "–", with: "--")
    }
}
