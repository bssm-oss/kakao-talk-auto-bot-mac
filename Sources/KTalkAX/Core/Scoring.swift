import Foundation

public enum ChatMatchMode: String, Codable {
    case exact
    case smart
    case fuzzy
}

public struct ScoredChatCandidate: Codable, Equatable, Sendable {
    let chatID: String
    let title: String
    let score: Int
    let matchType: String
    let sourceWindow: String
    let matchableTexts: [String]
    let unreadEstimate: Int?
    let metaEstimate: String?
}

struct MatchDecision {
    let selected: ScoredChatCandidate?
    let candidates: [ScoredChatCandidate]
    let ambiguous: Bool
}

enum Scoring {
    static func decide(
        query: String,
        rows: [ChatRowCandidate],
        mode: ChatMatchMode,
        preferredChatID: String?,
        registry: [ChatRegistryEntry]
    ) -> MatchDecision {
        let normalizedQuery = TextNormalizer.normalize(query)
        let strippedQuery = TextNormalizer.normalize(query, stripSeparators: true)
        var candidates: [ScoredChatCandidate] = rows.map { row in
            let best = score(query: query, normalizedQuery: normalizedQuery, strippedQuery: strippedQuery, row: row, mode: mode, preferredChatID: preferredChatID, registry: registry)
            return ScoredChatCandidate(
                chatID: row.chatID,
                title: row.title,
                score: best.score,
                matchType: best.reason,
                sourceWindow: row.sourceWindow,
                matchableTexts: row.matchableTexts,
                unreadEstimate: row.unreadEstimate,
                metaEstimate: row.metaEstimate
            )
        }
        .filter { $0.score > 0 }
        .sorted { lhs, rhs in
            if lhs.score == rhs.score { return lhs.title < rhs.title }
            return lhs.score > rhs.score
        }

        guard !candidates.isEmpty else {
            return MatchDecision(selected: nil, candidates: [], ambiguous: false)
        }

        if mode == .exact {
            candidates = candidates.filter { $0.score >= 100 }
        }

        guard let top = candidates.first else {
            return MatchDecision(selected: nil, candidates: [], ambiguous: false)
        }

        let second = candidates.dropFirst().first
        let isAmbiguous: Bool
        switch mode {
        case .exact:
            isAmbiguous = second?.score == top.score
        case .smart:
            isAmbiguous = second != nil && abs(top.score - (second?.score ?? 0)) < 10
        case .fuzzy:
            isAmbiguous = second != nil && abs(top.score - (second?.score ?? 0)) < 15
        }

        return MatchDecision(selected: isAmbiguous ? nil : top, candidates: candidates, ambiguous: isAmbiguous)
    }

    private static func score(
        query: String,
        normalizedQuery: String,
        strippedQuery: String,
        row: ChatRowCandidate,
        mode: ChatMatchMode,
        preferredChatID: String?,
        registry: [ChatRegistryEntry]
    ) -> (score: Int, reason: String) {
        var bestScore = 0
        var bestReason = "none"
        let texts = [row.title] + row.matchableTexts
        for (index, raw) in texts.enumerated() {
            let normalized = TextNormalizer.normalize(raw)
            let stripped = TextNormalizer.normalize(raw, stripSeparators: true)
            var score = 0
            var reason = "none"

            if normalized == normalizedQuery {
                score = 100
                reason = "exact_normalized"
            } else if stripped == strippedQuery && !strippedQuery.isEmpty {
                score = 95
                reason = "exact_stripped"
            } else if mode != .exact, normalized.hasPrefix(normalizedQuery), normalizedQuery.count >= 2 {
                score = 70
                reason = "prefix"
            } else if mode == .fuzzy, normalized.contains(normalizedQuery), normalizedQuery.count >= 2 {
                score = 50
                reason = "contains"
            }

            if index == 0 && score > 0 {
                score += 5
                reason += "_title"
            }

            if normalizedQuery.count <= 1 && score < 95 {
                score -= 30
            }

            if score > bestScore {
                bestScore = score
                bestReason = reason
            }
        }

        if preferredChatID == row.chatID {
            bestScore += 8
            bestReason += "_chatid"
        }

        if registry.contains(where: { $0.chatID == row.chatID || $0.normalizedTitle == normalizedQuery }) {
            bestScore += 6
            bestReason += "_registry"
        }

        return (max(0, bestScore), bestReason)
    }
}
