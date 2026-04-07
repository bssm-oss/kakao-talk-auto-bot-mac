import Foundation
import KTalkAXCore

@main
struct KTalkAXMCPMain {
    static func main() {
        let service = KTalkAXService()
        while let line = readLine(strippingNewline: true) {
            guard !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            do {
                let data = Data(line.utf8)
                let request = try JSONDecoder().decode(MCPRequest.self, from: data)
                let response = try handle(request: request, service: service)
                try write(response)
            } catch let error as KTalkAXError {
                try? write(MCPResponse(id: nil, result: nil, error: MCPError(code: Int(error.exitCode.rawValue), message: error.userFacingMessage)))
            } catch {
                try? write(MCPResponse(id: nil, result: nil, error: MCPError(code: -32603, message: error.localizedDescription)))
            }
        }
    }

    private static func handle(request: MCPRequest, service: KTalkAXService) throws -> MCPResponse {
        switch request.method {
        case "initialize":
            return MCPResponse(id: request.id, result: .object([
                "protocolVersion": .string("2024-11-05"),
                "serverInfo": .object([
                    "name": .string("katalk-ax-mcp"),
                    "version": .string("0.1.1")
                ]),
                "capabilities": .object([
                    "tools": .object([:])
                ])
            ]), error: nil)
        case "notifications/initialized":
            return MCPResponse(id: request.id, result: .object([:]), error: nil)
        case "tools/list":
            return MCPResponse(id: request.id, result: .object([
                "tools": .array([
                    tool(name: "katalk_status", description: "Get KakaoTalk Accessibility and process status", input: .object([:])),
                    tool(name: "katalk_chats", description: "List visible KakaoTalk chat candidates", input: .object([
                        "type": .string("object"),
                        "properties": .object([
                            "limit": .object(["type": .string("integer")])
                        ])
                    ])),
                    tool(name: "katalk_inspect", description: "Inspect the KakaoTalk AX tree", input: .object([
                        "type": .string("object"),
                        "properties": .object([
                            "depth": .object(["type": .string("integer")]),
                            "windowIndex": .object(["type": .string("integer")])
                        ])
                    ])),
                    tool(name: "katalk_send", description: "Dry-run or send a KakaoTalk message", input: .object([
                        "type": .string("object"),
                        "properties": .object([
                            "chat": .object(["type": .string("string")]),
                            "chatId": .object(["type": .string("string")]),
                            "message": .object(["type": .string("string")]),
                            "dryRun": .object(["type": .string("boolean")])
                        ]),
                        "required": .array([.string("message")])
                    ]))
                ])
            ]), error: nil)
        case "tools/call":
            guard let params = request.params?.objectValue,
                  case let .string(name)? = params["name"] else {
                return MCPResponse(id: request.id, result: nil, error: MCPError(code: -32602, message: "Missing tool name."))
            }
            let arguments = params["arguments"]?.objectValue ?? [:]
            let payload = try callTool(name: name, arguments: arguments, service: service)
            return MCPResponse(id: request.id, result: .object([
                "content": .array([
                    .object([
                        "type": .string("text"),
                        "text": .string(payload)
                    ])
                ])
            ]), error: nil)
        default:
            return MCPResponse(id: request.id, result: nil, error: MCPError(code: -32601, message: "Unknown method \(request.method)"))
        }
    }

    private static func callTool(name: String, arguments: [String: MCPValue], service: KTalkAXService) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        switch name {
        case "katalk_status":
            let result = try service.status()
            return String(decoding: try encoder.encode(result), as: UTF8.self)
        case "katalk_chats":
            let limit = arguments["limit"]?.intValue ?? 20
            let result = try service.chats(limit: limit)
            return String(decoding: try encoder.encode(result), as: UTF8.self)
        case "katalk_inspect":
            let depth = arguments["depth"]?.intValue ?? 4
            let windowIndex = arguments["windowIndex"]?.intValue
            return try service.inspectText(windowIndex: windowIndex, depth: depth)
        case "katalk_send":
            let result = try service.send(
                chat: arguments["chat"]?.stringValue,
                chatID: arguments["chatId"]?.stringValue,
                message: arguments["message"]?.stringValue ?? "",
                dryRun: arguments["dryRun"]?.boolValue ?? true
            )
            return String(decoding: try encoder.encode(result), as: UTF8.self)
        default:
            throw KTalkAXError.invalidArguments("알 수 없는 도구 \(name)입니다.")
        }
    }

    private static func tool(name: String, description: String, input: MCPValue) -> MCPValue {
        .object([
            "name": .string(name),
            "description": .string(description),
            "inputSchema": input
        ])
    }

    private static func write(_ response: MCPResponse) throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(response)
        FileHandle.standardOutput.write(data)
        FileHandle.standardOutput.write(Data("\n".utf8))
    }
}

private struct MCPRequest: Decodable {
    let jsonrpc: String?
    let id: MCPValue?
    let method: String
    let params: MCPValue?
}

private struct MCPResponse: Encodable {
    let jsonrpc = "2.0"
    let id: MCPValue?
    let result: MCPValue?
    let error: MCPError?
}

private struct MCPError: Encodable {
    let code: Int
    let message: String
}

private enum MCPValue: Codable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: MCPValue])
    case array([MCPValue])
    case null

    var stringValue: String? {
        if case let .string(value) = self { return value }
        return nil
    }

    var intValue: Int? {
        switch self {
        case .number(let value): return Int(value)
        case .string(let value): return Int(value)
        default: return nil
        }
    }

    var boolValue: Bool? {
        switch self {
        case .bool(let value): return value
        case .string(let value): return Bool(value)
        default: return nil
        }
    }

    var objectValue: [String: MCPValue]? {
        if case let .object(value) = self { return value }
        return nil
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null }
        else if let value = try? container.decode(Bool.self) { self = .bool(value) }
        else if let value = try? container.decode(Double.self) { self = .number(value) }
        else if let value = try? container.decode(String.self) { self = .string(value) }
        else if let value = try? container.decode([String: MCPValue].self) { self = .object(value) }
        else if let value = try? container.decode([MCPValue].self) { self = .array(value) }
        else { throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value") }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }
}
