import Foundation

struct LLMChatMessage: Codable, Sendable {
    let role: String
    let content: String
}

struct LLMChatRequest: Codable, Sendable {
    let model: String
    let messages: [LLMChatMessage]
    let temperature: Double
}

struct LLMChatResponse: Codable, Sendable {
    struct Choice: Codable, Sendable {
        struct Message: Codable, Sendable {
            let content: String
        }
        let message: Message
    }
    let choices: [Choice]
}

actor LLMService {
    static let shared = LLMService()

    func chat(messages: [LLMChatMessage], config: LLMConfig) async throws -> String {
        let url = URL(string: config.baseURL.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")

        let body = LLMChatRequest(
            model: config.model,
            messages: messages,
            temperature: 0.2
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw LLMError.httpError(statusCode: httpResponse.statusCode, body: String(data: data, encoding: .utf8) ?? "")
        }

        let result = try JSONDecoder().decode(LLMChatResponse.self, from: data)
        guard let content = result.choices.first?.message.content else {
            throw LLMError.noContent
        }
        return content
    }
}

enum LLMError: Error {
    case httpError(statusCode: Int, body: String)
    case noContent
}
