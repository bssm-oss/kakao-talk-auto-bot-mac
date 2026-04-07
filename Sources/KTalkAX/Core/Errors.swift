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
        case .notTrusted(let prompted):
            var message = "ACCESSIBILITY_PERMISSION_DENIED: 현재 실행 중인 프로세스에 접근성 권한이 없습니다.\n\n"
            message += "해결 방법:\n"
            message += "1. 시스템 설정 > 개인정보 보호 및 보안 > 손쉬운 사용으로 이동\n"
            message += "2. 다음 중 하나를 추가하고 권한을 켜세요:\n"
            message += "   - 터미널 앱 (Terminal.app, iTerm, Warp 등)\n"
            message += "   - 또는 빌드된 앱 번들: dist/katalk-ax-cli.app\n"
            message += "3. 앱을 재시작\n\n"
            if prompted {
                message += "시스템 권한 요청 대화상자가 표시되었어야 합니다. 표시되지 않았다면 Info.plist에 NSAccessibilityUsageDescription이 있는지 확인하세요."
            } else {
                message += "--prompt 옵션을 사용하면 시스템 권한 요청 대화상자를 표시할 수 있습니다: katalk-ax status --prompt"
            }
            return message
        case .ambiguousMatch(let query, let candidates):
            let names = candidates.prefix(5).map { "\($0.title) [\($0.chatID)] score=\($0.score)" }.joined(separator: ", ")
            return "채팅방 이름 '\(query)'이(가) 모호해서 메시지를 보내지 않았습니다. 후보: \(names)"
        }
    }
}
