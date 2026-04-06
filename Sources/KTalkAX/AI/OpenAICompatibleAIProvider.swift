import Foundation

public struct OpenAICompatibleAIProvider: AIProvider {
    public let configuration: AIProviderConfiguration

    public init(configuration: AIProviderConfiguration) {
        self.configuration = configuration
    }

    public func compose(request: AIComposeRequest) async throws -> AIComposeResult {
        guard let token = configuration.authToken, !token.isEmpty else {
            throw KTalkAXError.invalidArguments("OpenAI-compatible auth token is not configured.")
        }
        let model = configuration.model
        let baseURL = configuration.baseURL ?? "https://api.openai.com/v1"
        let url = URL(string: baseURL + "/responses")!
        var httpRequest = URLRequest(url: url)
        httpRequest.httpMethod = "POST"
        httpRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        httpRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        httpRequest.httpBody = try JSONEncoder().encode(OpenAICompatibleRequest(model: model, request: request))

        let (data, response) = try await URLSession.shared.data(for: httpRequest)
        try validateOpenAICompatibleHTTP(response: response, data: data)
        let decoded = try JSONDecoder().decode(OpenAICompatibleResponse.self, from: data)
        let text = decoded.output.flatMap { $0.content ?? [] }.compactMap { $0.text }.joined(separator: "\n")
        return AIComposeResult(provider: .openAICompatible, model: model, text: text)
    }
}

private struct OpenAICompatibleRequest: Encodable {
    struct InputMessage: Encodable {
        struct ContentPart: Encodable {
            let type = "input_text"
            let text: String
        }
        let role: String
        let content: [ContentPart]
    }

    let model: String
    let input: [InputMessage]

    init(model: String, request: AIComposeRequest) {
        self.model = model
        var messages: [InputMessage] = []
        if let systemPrompt = request.systemPrompt, !systemPrompt.isEmpty {
            messages.append(InputMessage(role: "system", content: [InputMessage.ContentPart(text: systemPrompt)]))
        }
        messages.append(contentsOf: request.conversation.map { InputMessage(role: $0.role, content: [InputMessage.ContentPart(text: $0.content)]) })
        messages.append(InputMessage(role: "user", content: [InputMessage.ContentPart(text: request.userPrompt)]))
        self.input = messages
    }
}

private struct OpenAICompatibleResponse: Decodable {
    struct Output: Decodable {
        struct Content: Decodable {
            let text: String?
        }
        let content: [Content]?
    }
    let output: [Output]
}

private func validateOpenAICompatibleHTTP(response: URLResponse, data: Data) throws {
    guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
        let body = String(decoding: data, as: UTF8.self)
        throw KTalkAXError.generic("OpenAI-compatible provider request failed: \(body)")
    }
}
