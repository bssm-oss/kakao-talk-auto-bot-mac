import Foundation

final class Logger {
    private let traceAXEnabled: Bool
    private let dateFormatter: ISO8601DateFormatter

    init(traceAX: Bool) {
        self.traceAXEnabled = traceAX
        self.dateFormatter = ISO8601DateFormatter()
    }

    func info(_ message: String) {
        emit("INFO", message)
    }

    func warn(_ message: String) {
        emit("WARN", message)
    }

    func trace(_ message: String) {
        guard traceAXEnabled else { return }
        emit("TRACE", message)
    }

    func recovery(_ message: String) {
        emit("RECOVERY", message)
    }

    func score(_ message: String) {
        guard traceAXEnabled else { return }
        emit("SCORE", message)
    }

    func timing(_ label: String, milliseconds: Int) {
        emit("TIMING", "\(label)=\(milliseconds)ms")
    }

    private func emit(_ level: String, _ message: String) {
        let line = "[\(dateFormatter.string(from: Date()))] [\(level)] \(message)\n"
        FileHandle.standardError.write(Data(line.utf8))
    }
}
