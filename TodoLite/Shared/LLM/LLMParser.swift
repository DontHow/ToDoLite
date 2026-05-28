import Foundation

actor LLMParser {
    static let shared = LLMParser()

    private let service = LLMService.shared

    func parse(_ input: String, projects: [Project], tags: [TagItem], config: LLMConfig) async throws -> TodoDraft {
        let projectList = projects.map { "- \($0.name)" }.joined(separator: "\n")
        let tagList = tags.map { "- \($0.name)" }.joined(separator: "\n")

        let systemPrompt = """
        You are a task parsing assistant. Parse the user's natural language task description into structured data.

        Available projects (match by name, or null if none match):
        \(projectList.isEmpty ? "(none)" : projectList)

        Available tags (match by name, or empty array if none match):
        \(tagList.isEmpty ? "(none)" : tagList)

        Date format for dueAt: ISO8601 string (yyyy-MM-dd) or null.
        If user mentions relative dates, convert to absolute date.

        Respond ONLY with a JSON object in this exact format:
        {
          "title": "extracted task title",
          "description": "optional detailed description, or empty string",
          "projectName": "matched project name or null",
          "tagNames": ["matched tag names"],
          "dueAt": "yyyy-MM-dd or null"
        }
        """

        let userPrompt = "Parse this task: \"\(input)\""

        let content = try await service.chat(
            messages: [
                LLMChatMessage(role: "system", content: systemPrompt),
                LLMChatMessage(role: "user", content: userPrompt)
            ],
            config: config
        )

        let jsonString = extractJSON(from: content)
        guard let data = jsonString.data(using: .utf8) else {
            throw LLMParserError.invalidResponse
        }

        let parsed = try JSONDecoder().decode(LLMJSONDraft.self, from: data)

        var draft = TodoDraft()
        draft.title = parsed.title
        draft.description = parsed.description ?? ""
        draft.projectName = parsed.projectName
        draft.tagNames = parsed.tagNames ?? []
        draft.dueAt = parsed.dueAt.flatMap { dateFromString($0) }

        return draft
    }

    private func extractJSON(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("{") {
            return trimmed
        }
        // Extract JSON from markdown code block
        if let start = trimmed.range(of: "```json"),
           let end = trimmed.range(of: "```", range: start.upperBound..<trimmed.endIndex) {
            return String(trimmed[start.upperBound..<end.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let start = trimmed.range(of: "```"),
           let end = trimmed.range(of: "```", range: start.upperBound..<trimmed.endIndex) {
            return String(trimmed[start.upperBound..<end.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return trimmed
    }

    private func dateFromString(_ string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        return formatter.date(from: string)
    }
}

struct LLMJSONDraft: Codable {
    let title: String
    let description: String?
    let projectName: String?
    let tagNames: [String]?
    let dueAt: String?
}

enum LLMParserError: Error {
    case invalidResponse
}
