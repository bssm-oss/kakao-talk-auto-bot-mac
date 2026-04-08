import Foundation
import ApplicationServices
import KTalkAXCore

func writeJSON<T: Encodable>(_ value: T) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    let data = try encoder.encode(value)
    FileHandle.standardOutput.write(data)
    FileHandle.standardOutput.write(Data("\n".utf8))
}

func readFlagValue(_ flag: String, in arguments: [String]) -> String? {
    guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else { return nil }
    return arguments[index + 1]
}

if CommandLine.arguments.contains("--print-accessibility-status") {
    let trusted = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": false] as CFDictionary)
    let payload = "{\"trusted\":\(trusted ? "true" : "false")}" + "\n"
    FileHandle.standardOutput.write(Data(payload.utf8))
    exit(0)
}

if CommandLine.arguments.contains("--prompt-accessibility-status") {
    let trusted = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    let payload = "{\"trusted\":\(trusted ? "true" : "false")}" + "\n"
    FileHandle.standardOutput.write(Data(payload.utf8))
    exit(0)
}

if let depth = readFlagValue("--inspect-depth", in: CommandLine.arguments).flatMap(Int.init) {
    let windowIndex = readFlagValue("--inspect-window", in: CommandLine.arguments).flatMap(Int.init)
    let service = KTalkAXService()
    do {
        let text = try service.inspectText(windowIndex: windowIndex, depth: depth)
        FileHandle.standardOutput.write(Data((text + "\n").utf8))
        exit(0)
    } catch let error as KTalkAXError {
        FileHandle.standardError.write(Data((error.userFacingMessage + "\n").utf8))
        exit(error.exitCode.rawValue)
    } catch {
        FileHandle.standardError.write(Data(("예상하지 못한 오류: \(error.localizedDescription)\n").utf8))
        exit(ExitCode.genericError.rawValue)
    }
}

if let room = readFlagValue("--send-room", in: CommandLine.arguments),
   let message = readFlagValue("--send-message", in: CommandLine.arguments) {
    let json = CommandLine.arguments.contains("--json")
    let traceAX = CommandLine.arguments.contains("--trace-ax")
    let dryRun = CommandLine.arguments.contains("--dry-run")
    let service = KTalkAXService()
    do {
        let result = try service.send(chat: room, message: message, dryRun: dryRun, traceAX: traceAX)
        if json {
            try writeJSON(result)
        } else {
            FileHandle.standardOutput.write(Data((result.textDescription + "\n").utf8))
        }
        exit(0)
    } catch let error as KTalkAXError {
        FileHandle.standardError.write(Data((error.userFacingMessage + "\n").utf8))
        exit(error.exitCode.rawValue)
    } catch {
        FileHandle.standardError.write(Data(("예상하지 못한 오류: \(error.localizedDescription)\n").utf8))
        exit(ExitCode.genericError.rawValue)
    }
}

import KTalkAXMenuBarApp
KTalkAXMenuBarLauncher.run()
