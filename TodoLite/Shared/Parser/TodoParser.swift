import Foundation

struct TodoParser {
    static func parse(_ input: String) -> TodoDraft {
        var draft = TodoDraft()
        var remaining = input

        // Extract @project
        if let projectMatch = remaining.range(of: #"@(\S+)"#, options: .regularExpression) {
            let matched = String(remaining[projectMatch])
            draft.projectName = String(matched.dropFirst())
            remaining.removeSubrange(projectMatch)
        }

        // Extract #tags
        let tagPattern = #"#(\S+)"#
        while let tagMatch = remaining.range(of: tagPattern, options: .regularExpression) {
            let matched = String(remaining[tagMatch])
            draft.tagNames.append(String(matched.dropFirst()))
            remaining.removeSubrange(tagMatch)
        }

        // Extract !priority
        if let priorityMatch = remaining.range(of: #"!(low|medium|high)"#, options: [.regularExpression, .caseInsensitive]) {
            let matched = String(remaining[priorityMatch]).lowercased()
            switch matched {
            case "!low": draft.priority = .low
            case "!high": draft.priority = .high
            default: draft.priority = .medium
            }
            remaining.removeSubrange(priorityMatch)
        }

        // Extract ^date
        if let dateMatch = remaining.range(of: #"\^(\S+)"#, options: .regularExpression) {
            let matched = String(remaining[dateMatch])
            let dateInput = String(matched.dropFirst())
            draft.scheduledAt = DateResolver.resolve(dateInput)
            remaining.removeSubrange(dateMatch)
        }

        // Remaining is title
        draft.title = remaining.trimmingCharacters(in: .whitespacesAndNewlines)

        return draft
    }
}
