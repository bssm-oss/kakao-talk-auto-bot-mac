import Foundation

public struct GeminiAIProvider: AIProvider {
    public let configuration: AIProviderConfiguration

    public init(configuration: AIProviderConfiguration) {
        self.configuration = configuration
    }

    public func compose(request: AIComposeRequest) async throws -> AIComposeResult {
        guard let apiKey = configuration.apiKey, !apiKey.isEmpty else {
            throw KTalkAXError.invalidArguments("Gemini API key is not configured.")
        }
        let model = configuration.model
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)")!
        var httpRequest = URLRequest(url: url)
        httpRequest.httpMethod = "POST"
        httpRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        httpRequest.httpBody = try JSONEncoder().encode(GeminiRequest(from: request))

        let (data, response) = try await URLSession.shared.data(for: httpRequest)
        try validateHTTP(response: response, data: data)
        let decoded = try JSONDecoder().decode(GeminiResponse.self, from: data)
        let text = decoded.candidates.first?.content.parts.compactMap(\.text).joined(separator: "\n") ?? ""
        return AIComposeResult(provider: .gemini, model: model, text: text)
    }
}

private struct GeminiRequest: Encodable {
    struct Content: Encodable {
        struct Part: Encodable {
            let text: String
        }
        let role: String
        let parts: [Part]
    }

    let systemInstruction: Content?
    let contents: [Content]

    init(from request: AIComposeRequest) {
        self.systemInstruction = request.systemPrompt.map { Content(role: "user", parts: [Content.Part(text: $0)]) }
        var messages = request.conversation.map { Content(role: $0.role, parts: [Content.Part(text: $0.content)]) }
        messages.append(Content(role: "user", parts: [Content.Part(text: request.userPrompt)]))
        self.contents = messages
    }
}

private struct GeminiResponse: Decodable {
    struct Candidate: Decodable {
        struct Content: Decodable {
            struct Part: Decodable {
                let text: String?
            }
            let parts: [Part]
        }
        let content: Content
    }
    let candidates: [Candidate]
}

private func validateHTTP(response: URLResponse, data: Data) throws {
    guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
        let body = String(decoding: data, as: UTF8.self)
        throw KTalkAXError.generic("AI provider request failed: \(body)")
    }
}
