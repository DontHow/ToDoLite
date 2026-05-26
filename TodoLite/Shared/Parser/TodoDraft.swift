import Foundation

struct TodoDraft {
    var title: String = ""
    var projectName: String?
    var tagNames: [String] = []
    var priority: TodoPriority?
    var scheduledAt: Date?
    var dueAt: Date?
}
