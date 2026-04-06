import Foundation

struct ResultPrinter {
    let outputJSON: Bool

    func printResult<T: Encodable>(_ result: T, text: String) throws {
        if outputJSON {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(result)
            FileHandle.standardOutput.write(data)
            FileHandle.standardOutput.write(Data("\n".utf8))
        } else {
            FileHandle.standardOutput.write(Data((text + "\n").utf8))
        }
    }
}
