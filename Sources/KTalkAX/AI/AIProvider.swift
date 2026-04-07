import Foundation

public protocol AIProvider: Sendable {
    var configuration: AIProviderConfiguration { get }
    func compose(request: AIComposeRequest) async throws -> AIComposeResult
}

public final class AIComposerService: @unchecked Sendable {
    private let providers: [AIProviderKind: any AIProvider]

    public init(providers: [any AIProvider]) {
        self.providers = Dictionary(uniqueKeysWithValues: providers.map { ($0.configuration.provider, $0) })
    }

    public convenience init(credentialStore: AICredentialStore = AICredentialStore()) {
        let providers = credentialStore.loadConfigurations().compactMap { configuration -> (any AIProvider)? in
            switch configuration.provider {
            case .gemini:
                return GeminiAIProvider(configuration: configuration)
            case .openAICompatible:
                return OpenAICompatibleAIProvider(configuration: configuration)
            }
        }
        self.init(providers: providers)
    }

    public var availableProviders: [AIProviderKind] {
        Array(providers.keys).sorted { $0.rawValue < $1.rawValue }
    }

    public func compose(using provider: AIProviderKind, request: AIComposeRequest) async throws -> AIComposeResult {
        guard let providerImpl = providers[provider] else {
            throw KTalkAXError.invalidArguments("AI 제공자 \(provider.rawValue)가 설정되어 있지 않습니다.")
        }
        return try await providerImpl.compose(request: request)
    }
}
