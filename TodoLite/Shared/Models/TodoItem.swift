import Foundation

struct TodoItem: Codable, Identifiable, Hashable, Sendable {
    var id: String

    var title: String
    var description: String

    var status: TodoStatus
    var priority: TodoPriority

    var projectId: String?

    var tagIds: [String]

    var scheduledAt: Date?
    var dueAt: Date?

    var createdAt: Date
    var updatedAt: Date
    var completedAt: Date?

    var version: Int

    init(
        id: String = UUID().uuidString,
        title: String,
        description: String = "",
        status: TodoStatus = .inbox,
        priority: TodoPriority = .medium,
        projectId: String? = nil,
        tagIds: [String] = [],
        scheduledAt: Date? = nil,
        dueAt: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        completedAt: Date? = nil,
        version: Int = 1
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.status = status
        self.priority = priority
        self.projectId = projectId
        self.tagIds = tagIds
        self.scheduledAt = scheduledAt
        self.dueAt = dueAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.completedAt = completedAt
        self.version = version
    }
}
