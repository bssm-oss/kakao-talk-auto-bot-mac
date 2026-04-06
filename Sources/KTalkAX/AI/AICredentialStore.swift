import Foundation

public final class AICredentialStore {
    public struct StoredConfigurationFile: Codable {
        public let providers: [AIProviderConfiguration]
    }

    public let configURL: URL
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let root = fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".katalk-ax", isDirectory: true)
        self.configURL = root.appendingPathComponent("ai-providers.json")
    }

    public func loadConfigurations() -> [AIProviderConfiguration] {
        var configurations: [AIProviderConfiguration] = []
        if let data = try? Data(contentsOf: configURL),
           let file = try? JSONDecoder().decode(StoredConfigurationFile.self, from: data) {
            configurations.append(contentsOf: file.providers)
        }

        if let geminiKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"], !geminiKey.isEmpty {
            configurations.append(AIProviderConfiguration(provider: .gemini, model: ProcessInfo.processInfo.environment["GEMINI_MODEL"] ?? "gemini-1.5-flash", apiKey: geminiKey))
        }

        if let openAIToken = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !openAIToken.isEmpty {
            configurations.append(AIProviderConfiguration(provider: .openAICompatible, model: ProcessInfo.processInfo.environment["OPENAI_MODEL"] ?? "gpt-4.1-mini", baseURL: ProcessInfo.processInfo.environment["OPENAI_BASE_URL"] ?? "https://api.openai.com/v1", authToken: openAIToken))
        }

        return configurations
    }

    public func saveConfigurations(_ configurations: [AIProviderConfiguration]) throws {
        let root = configURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: root.path) {
            try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(StoredConfigurationFile(providers: configurations))
        try data.write(to: configURL, options: .atomic)
    }
}
