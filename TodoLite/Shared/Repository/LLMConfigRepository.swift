import Foundation

actor LLMConfigRepository {
    static let shared = LLMConfigRepository()

    private let fs = FileSystemManager.shared
    private let filename = "llm_config.json"

    func save(_ config: LLMConfig) async throws {
        try await fs.write(config, filename: filename, directory: .config)
    }

    func load() async throws -> LLMConfig {
        try await fs.read(LLMConfig.self, filename: filename, directory: .config)
    }

    func loadOrDefault() async -> LLMConfig {
        do {
            return try await load()
        } catch {
            return LLMConfig()
        }
    }
}
