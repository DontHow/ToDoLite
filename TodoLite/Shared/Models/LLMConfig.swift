import Foundation

struct LLMConfig: Codable, Sendable {
    var apiKey: String
    var baseURL: String
    var model: String

    init(
        apiKey: String = "",
        baseURL: String = "https://api.openai.com/v1",
        model: String = "gpt-4o-mini"
    ) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.model = model
    }
}
