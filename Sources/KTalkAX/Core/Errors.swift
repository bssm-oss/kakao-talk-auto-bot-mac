import Foundation

public enum ExitCode: Int32 {
    case success = 0
    case genericError = 1
    case accessibilityPermissionDenied = 2
    case kakaoTalkNotAvailable = 3
    case chatNotFound = 4
    case ambiguousChat = 5
    case composeFieldNotFound = 6
    case sendFailed = 7
    case verificationFailed = 8
    case invalidArguments = 9
}

public enum KTalkAXError: Error {
    case timeout(String)
    case noValue(String)
    case notTrusted(prompted: Bool)
    case unsupported(String)
    case cannotComplete(String)
    case invalidUI(String)
    case ambiguousMatch(String, [ScoredChatCandidate])
    case verificationFailed(String)
    case invalidArguments(String)
    case generic(String)
    case io(String)
    case kakaoTalkNotAvailable(String)
    case chatNotFound(String)
    case composeFieldNotFound(String)
    case sendFailed(String)
    case loginRequired(String)
    case locked(String)
}

extension KTalkAXError {
    public var exitCode: ExitCode {
        switch self {
        case .notTrusted: return .accessibilityPermissionDenied
        case .kakaoTalkNotAvailable: return .kakaoTalkNotAvailable
        case .chatNotFound: return .chatNotFound
        case .ambiguousMatch: return .ambiguousChat
        case .composeFieldNotFound: return .composeFieldNotFound
        case .sendFailed: return .sendFailed
        case .verificationFailed: return .verificationFailed
        case .invalidArguments: return .invalidArguments
        case .loginRequired, .locked, .timeout, .noValue, .unsupported, .cannotComplete, .invalidUI, .generic, .io:
            return .genericError
        }
    }

    public var errorCode: String {
        switch self {
        case .timeout: return "TIMEOUT"
        case .noValue: return "NO_VALUE"
        case .notTrusted: return "ACCESSIBILITY_PERMISSION_DENIED"
        case .unsupported: return "UNSUPPORTED"
        case .cannotComplete: return "CANNOT_COMPLETE"
        case .invalidUI: return "INVALID_UI"
        case .ambiguousMatch: return "AMBIGUOUS_CHAT"
        case .verificationFailed: return "VERIFICATION_FAILED"
        case .invalidArguments: return "INVALID_ARGUMENTS"
        case .generic: return "GENERIC_ERROR"
        case .io: return "IO_ERROR"
        case .kakaoTalkNotAvailable: return "KAKAOTALK_NOT_AVAILABLE"
        case .chatNotFound: return "CHAT_NOT_FOUND"
        case .composeFieldNotFound: return "COMPOSE_FIELD_NOT_FOUND"
        case .sendFailed: return "SEND_FAILED"
        case .loginRequired: return "LOGIN_REQUIRED"
        case .locked: return "APP_LOCKED"
        }
    }

    public var userFacingMessage: String {
        switch self {
        case .timeout(let message),
             .noValue(let message),
             .unsupported(let message),
             .cannotComplete(let message),
             .invalidUI(let message),
             .verificationFailed(let message),
             .invalidArguments(let message),
             .generic(let message),
             .io(let message),
             .kakaoTalkNotAvailable(let message),
             .chatNotFound(let message),
             .composeFieldNotFound(let message),
             .sendFailed(let message),
             .loginRequired(let message),
             .locked(let message):
            return message
        case .notTrusted:
            return "Accessibility permission is not granted for the current process. Enable it in System Settings > Privacy & Security > Accessibility, then rerun katalk-ax."
        case .ambiguousMatch(let query, let candidates):
            let names = candidates.prefix(5).map { "\($0.title) [\($0.chatID)] score=\($0.score)" }.joined(separator: ", ")
            return "Chat name '\(query)' is ambiguous. No message was sent. Candidates: \(names)"
        }
    }
}
