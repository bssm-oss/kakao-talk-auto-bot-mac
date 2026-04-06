import Testing
@testable import KTalkAXCore

struct ScoringTests {
    @Test func exactMatchWins() {
        let rows = [
            ChatRowCandidate(chatID: "chat_1", title: "홍길동", sourceWindow: "main", matchableTexts: ["홍길동"], unreadEstimate: nil, metaEstimate: nil, rowElement: AXElement.systemWideElement()),
            ChatRowCandidate(chatID: "chat_2", title: "홍길동 공지", sourceWindow: "main", matchableTexts: ["홍길동 공지"], unreadEstimate: nil, metaEstimate: nil, rowElement: AXElement.systemWideElement())
        ]
        let registry = ChatRegistryStore(entries: [])
        let decision = Scoring.decide(query: "홍길동", rows: rows, mode: .exact, preferredChatID: nil, registry: registry.entries)
        #expect(decision.selected?.chatID == "chat_1")
        #expect(decision.ambiguous == false)
    }

    @Test func fuzzyAmbiguityBlocksCloseScores() {
        let rows = [
            ChatRowCandidate(chatID: "chat_1", title: "개발팀", sourceWindow: "main", matchableTexts: ["개발팀"], unreadEstimate: nil, metaEstimate: nil, rowElement: AXElement.systemWideElement()),
            ChatRowCandidate(chatID: "chat_2", title: "개발팀 공지", sourceWindow: "main", matchableTexts: ["개발팀 공지"], unreadEstimate: nil, metaEstimate: nil, rowElement: AXElement.systemWideElement())
        ]
        let decision = Scoring.decide(query: "개발팀", rows: rows, mode: .fuzzy, preferredChatID: nil, registry: [])
        #expect(decision.ambiguous)
        #expect(decision.selected == nil)
    }

    @Test func preferredChatIDAddsBias() {
        let rows = [
            ChatRowCandidate(chatID: "chat_1", title: "테스트", sourceWindow: "main", matchableTexts: ["테스트"], unreadEstimate: nil, metaEstimate: nil, rowElement: AXElement.systemWideElement())
        ]
        let decision = Scoring.decide(query: "테스트", rows: rows, mode: .smart, preferredChatID: "chat_1", registry: [])
        #expect(decision.selected?.chatID == "chat_1")
        #expect((decision.selected?.score ?? 0) > 100)
    }
}
