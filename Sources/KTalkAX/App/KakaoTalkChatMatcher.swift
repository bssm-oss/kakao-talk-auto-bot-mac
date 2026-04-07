import Foundation

final class KakaoTalkChatMatcher {
    private let logger: Logger

    init(logger: Logger) {
        self.logger = logger
    }

    func match(query: String, rows: [ChatRowCandidate], mode: ChatMatchMode, preferredChatID: String?, registry: KakaoTalkRegistry) throws -> ScoredChatCandidate {
        let decision = Scoring.decide(query: query, rows: rows, mode: mode, preferredChatID: preferredChatID, registry: registry.entries())
        decision.candidates.forEach { candidate in
            logger.score("title='\(candidate.title)' score=\(candidate.score) match=\(candidate.matchType)")
        }
        if decision.candidates.isEmpty {
            throw KTalkAXError.chatNotFound("'\(query)'에 해당하는 접근 가능한 KakaoTalk 채팅방을 찾지 못했습니다.")
        }
        if decision.ambiguous {
            throw KTalkAXError.ambiguousMatch(query, decision.candidates)
        }
        guard let selected = decision.selected else {
            throw KTalkAXError.chatNotFound("'\(query)'에 해당하는 접근 가능한 KakaoTalk 채팅방을 찾지 못했습니다.")
        }
        return selected
    }
}
