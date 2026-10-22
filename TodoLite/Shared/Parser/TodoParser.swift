import Foundation

struct TodoParser {
    static func parse(_ input: String, from date: Date = Date(), calendar: Calendar = .current) -> TodoDraft {
        var draft = TodoDraft()
        // 规则只允许出现在输入开头或空白后，保留邮箱、URL 和 C# 等普通文本。
        let pattern = #"(?<!\S)([@#^])(\S+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return draft }
        var consumed: [Range<String.Index>] = []
        for match in regex.matches(in: input, range: NSRange(input.startIndex..., in: input)) {
            guard let token = Range(match.range, in: input),
                  let symbolRange = Range(match.range(at: 1), in: input),
                  let valueRange = Range(match.range(at: 2), in: input) else { continue }
            let value = String(input[valueRange])
            switch input[symbolRange] {
            case "@" where draft.projectName == nil:
                draft.projectName = value
                consumed.append(token)
            case "#":
                if !draft.tagNames.contains(value) { draft.tagNames.append(value) }
                consumed.append(token)
            case "^" where draft.dueAt == nil:
                var range = token
                var dateInput = value
                if value.lowercased() == "next",
                   let suffix = input[token.upperBound...].range(of: #"^[ \t]+week(?=\s|$)"#, options: [.regularExpression, .caseInsensitive]) {
                    range = token.lowerBound..<suffix.upperBound
                    dateInput = "next week"
                }
                if let resolved = DateResolver.resolve(dateInput, from: date, calendar: calendar) {
                    draft.dueAt = resolved
                    consumed.append(range)
                }
            default:
                break
            }
        }
        var remaining = input
        for range in consumed.reversed() { remaining.removeSubrange(range) }
        draft.title = consumed.isEmpty
            ? remaining.trimmingCharacters(in: .whitespacesAndNewlines)
            : remaining.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        return draft
    }
}
