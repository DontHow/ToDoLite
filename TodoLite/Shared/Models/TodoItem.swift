import Foundation

struct TodoItem: Codable, Identifiable, Hashable, Sendable {
    var id: String

    var title: String
    var description: String

    var status: TodoStatus

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

enum TodoReschedulePreset: CaseIterable, Identifiable {
    case threeDays
    case oneWeek
    case oneMonth

    var id: Self { self }

    var title: String {
        switch self {
        case .threeDays: return "3 天后"
        case .oneWeek: return "一周后"
        case .oneMonth: return "一月后"
        }
    }

    func dueDate(from date: Date = Date(), calendar: Calendar = .current) -> Date? {
        let today = calendar.startOfDay(for: date)
        switch self {
        case .threeDays:
            return calendar.date(byAdding: .day, value: 3, to: today)
        case .oneWeek:
            return calendar.date(byAdding: .day, value: 7, to: today)
        case .oneMonth:
            return calendar.date(byAdding: .month, value: 1, to: today)
        }
    }
}
