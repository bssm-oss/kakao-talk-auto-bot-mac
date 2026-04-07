import Foundation
import KTalkAXCore

enum AIDraftAction: Sendable {
    case draft
    case rewrite

    var progressMessage: String {
        switch self {
        case .draft:
            return "AI 초안을 생성하는 중…"
        case .rewrite:
            return "현재 초안을 AI로 다듬는 중…"
        }
    }

    var successVerb: String {
        switch self {
        case .draft:
            return "초안 생성 완료"
        case .rewrite:
            return "문장 다듬기 완료"
        }
    }
}

extension AIProviderKind {
    var displayName: String {
        switch self {
        case .gemini:
            return "제미나이"
        case .openAICompatible:
            return "OpenAI 호환"
        }
    }
}

struct AIDraftRequestFactory {
    static func makeRequest(
        action: AIDraftAction,
        chatTitle: String,
        instructions: String,
        currentMessage: String
    ) -> AIComposeRequest {
        let trimmedInstructions = instructions.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedMessage = currentMessage.trimmingCharacters(in: .whitespacesAndNewlines)

        switch action {
        case .draft:
            return AIComposeRequest(
                systemPrompt: "You help write KakaoTalk message drafts for a native macOS automation app. Return only the final message text without commentary, bullets, or markdown.",
                userPrompt: draftPrompt(
                    chatTitle: chatTitle,
                    instructions: trimmedInstructions,
                    currentMessage: trimmedMessage
                )
            )
        case .rewrite:
            return AIComposeRequest(
                systemPrompt: "You revise KakaoTalk message drafts for a native macOS automation app. Preserve the user's intent and concrete facts unless the request says otherwise. Return only the final message text without commentary, bullets, or markdown.",
                userPrompt: rewritePrompt(
                    chatTitle: chatTitle,
                    instructions: trimmedInstructions,
                    currentMessage: trimmedMessage
                )
            )
        }
    }

    private static func draftPrompt(chatTitle: String, instructions: String, currentMessage: String) -> String {
        var sections = [
            "Draft a KakaoTalk message for the chat named \"\(chatTitle)\".",
            "Write something the user can review and send as-is."
        ]

        if !instructions.isEmpty {
            sections.append("Draft instructions:\n\(instructions)")
        }

        if !currentMessage.isEmpty {
            sections.append("Existing notes or partial draft:\n\(currentMessage)")
        }

        sections.append("Keep the tone natural and concise unless the instructions say otherwise.")
        return sections.joined(separator: "\n\n")
    }

    private static func rewritePrompt(chatTitle: String, instructions: String, currentMessage: String) -> String {
        let rewriteGoal = instructions.isEmpty
            ? "Improve clarity, flow, and tone while keeping the same intent."
            : instructions

        return [
            "Rewrite this KakaoTalk message for the chat named \"\(chatTitle)\".",
            "Rewrite instructions:\n\(rewriteGoal)",
            "Current draft:\n\(currentMessage)"
        ].joined(separator: "\n\n")
    }
}

final class AIDraftWorkflow: @unchecked Sendable {
    private let credentialStore: AICredentialStore

    init(credentialStore: AICredentialStore = AICredentialStore()) {
        self.credentialStore = credentialStore
    }

    var configurationPath: String {
        credentialStore.configURL.path
    }

    var availableProviders: [AIProviderKind] {
        AIComposerService(credentialStore: credentialStore).availableProviders
    }

    func compose(
        action: AIDraftAction,
        provider: AIProviderKind,
        chatTitle: String,
        instructions: String,
        currentMessage: String
    ) async throws -> AIComposeResult {
        let request = AIDraftRequestFactory.makeRequest(
            action: action,
            chatTitle: chatTitle,
            instructions: instructions,
            currentMessage: currentMessage
        )
        let composer = AIComposerService(credentialStore: credentialStore)
        return try await composer.compose(using: provider, request: request)
    }

    func ask(
        provider: AIProviderKind,
        chatTitle: String,
        prompt: String,
        currentMessage: String,
        conversation: [AIChatTurn]
    ) async throws -> AIComposeResult {
        let request = AIComposeRequest(
            systemPrompt: "You are helping inside a native macOS KakaoTalk assistant. Be concise, practical, and conversational. If the user seems to want a sendable message, provide a polished reply they can review before sending.",
            conversation: conversation,
            userPrompt: [
                "Current KakaoTalk chat title: \(chatTitle)",
                currentMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : "Current draft:\n\(currentMessage)",
                "User request:\n\(prompt)"
            ].compactMap { $0 }.joined(separator: "\n\n")
        )
        let composer = AIComposerService(credentialStore: credentialStore)
        return try await composer.compose(using: provider, request: request)
    }
}
