import Foundation
import KTalkAXCore

do {
    let parser = CLIArgumentParser(arguments: CommandLine.arguments)
    let command = try parser.parse()
    let app = KTalkAXApplication(command: command)
    let exitCode = try app.run()
    exit(exitCode.rawValue)
} catch let error as KTalkAXError {
    FileHandle.standardError.write(Data((error.userFacingMessage + "\n").utf8))
    exit(error.exitCode.rawValue)
} catch {
    FileHandle.standardError.write(Data(("Unexpected error: \(error.localizedDescription)\n").utf8))
    exit(ExitCode.genericError.rawValue)
}
