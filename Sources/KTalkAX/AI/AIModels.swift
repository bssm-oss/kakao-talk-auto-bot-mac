import Foundation

public enum AIProviderKind: String, Codable, CaseIterable, Sendable {
    case gemini
    case openAICompatible = "openai-compatible"
}

public struct AIChatTurn: Codable, Sendable {
    public let role: String
    public let content: String

    public init(role: String, content: String) {
        self.role = role
        self.content = content
    }
}

public struct AIComposeRequest: Codable, Sendable {
    public let systemPrompt: String?
    public let conversation: [AIChatTurn]
    public let userPrompt: String

    public init(systemPrompt: String? = nil, conversation: [AIChatTurn] = [], userPrompt: String) {
        self.systemPrompt = systemPrompt
        self.conversation = conversation
        self.userPrompt = userPrompt
    }
}

public struct AIComposeResult: Codable, Sendable {
    public let provider: AIProviderKind
    public let model: String
    public let text: String

    public init(provider: AIProviderKind, model: String, text: String) {
        self.provider = provider
        self.model = model
        self.text = text
    }
}

public struct AIProviderConfiguration: Codable, Sendable {
    public let provider: AIProviderKind
    public let model: String
    public let baseURL: String?
    public let apiKey: String?
    public let authToken: String?

    public init(provider: AIProviderKind, model: String, baseURL: String? = nil, apiKey: String? = nil, authToken: String? = nil) {
        self.provider = provider
        self.model = model
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.authToken = authToken
    }
}
