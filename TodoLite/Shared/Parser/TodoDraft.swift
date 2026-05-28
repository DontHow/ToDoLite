import Foundation

struct TodoDraft {
    var title: String = ""
    var description: String = ""
    var projectName: String?
    var tagNames: [String] = []
    var dueAt: Date?
}
