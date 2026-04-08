import Foundation
import KTalkAXCore

let parser = KabotCommandParser()

do {
    if let command = try parser.parse(arguments: CommandLine.arguments) {
        let service = KTalkAXService()
        let result = try service.send(
            chat: command.room,
            message: command.message,
            dryRun: command.dryRun,
            traceAX: command.traceAX
        )

        if command.json {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(result)
            FileHandle.standardOutput.write(data)
            FileHandle.standardOutput.write(Data("\n".utf8))
        } else {
            FileHandle.standardOutput.write(Data((result.textDescription + "\n").utf8))
        }
        exit(ExitCode.success.rawValue)
    } else {
        print(parser.helpText())
        exit(ExitCode.success.rawValue)
    }
} catch let error as KTalkAXError {
    FileHandle.standardError.write(Data((error.userFacingMessage + "\n").utf8))
    exit(error.exitCode.rawValue)
} catch {
    FileHandle.standardError.write(Data(("예상하지 못한 오류: \(error.localizedDescription)\n").utf8))
    exit(ExitCode.genericError.rawValue)
}
