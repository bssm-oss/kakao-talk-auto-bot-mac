import Foundation

enum Timeout {
    static func poll<T>(
        label: String,
        timeout: TimeInterval,
        interval: TimeInterval = 0.2,
        operation: () throws -> T?
    ) throws -> T {
        let startedAt = Date()
        while Date().timeIntervalSince(startedAt) < timeout {
            if let value = try operation() {
                return value
            }
            Thread.sleep(forTimeInterval: interval)
        }
        throw KTalkAXError.timeout("\(label)을(를) 기다리다가 시간이 초과되었습니다.")
    }

    static func sleep(for speed: SendSpeed, base: TimeInterval = 0.15) {
        Thread.sleep(forTimeInterval: max(0.05, base * speed.delayMultiplier))
    }
}
