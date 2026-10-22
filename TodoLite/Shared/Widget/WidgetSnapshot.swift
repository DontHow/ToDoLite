import Foundation

struct WidgetTask: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let title: String
}

struct WidgetData: Codable, Equatable, Sendable {
    let focusDate: String
    let count: Int
    let tasks: [WidgetTask]
    let updatedAt: Date

    private enum CodingKeys: String, CodingKey { case focusDate, count, tasks, updatedAt }

    init(focusDate: String, count: Int, tasks: [WidgetTask], updatedAt: Date) {
        self.focusDate = focusDate
        self.count = count
        self.tasks = tasks
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        // 旧快照没有关注日期，不能证明属于今天；读取后按过期数据处理。
        focusDate = try values.decodeIfPresent(String.self, forKey: .focusDate) ?? ""
        count = try values.decode(Int.self, forKey: .count)
        tasks = try values.decodeIfPresent([WidgetTask].self, forKey: .tasks) ?? []
        updatedAt = try values.decode(Date.self, forKey: .updatedAt)
    }

    static func empty(at date: Date, calendar: Calendar = .current) -> WidgetData {
        WidgetData(focusDate: dayString(for: date, calendar: calendar), count: 0, tasks: [], updatedAt: date)
    }

    static func dayString(for date: Date, calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    func validSnapshot(at date: Date, calendar: Calendar = .current) -> WidgetData {
        focusDate == Self.dayString(for: date, calendar: calendar) ? self : .empty(at: date, calendar: calendar)
    }
}

enum WidgetSnapshotStore {
    static let suiteName = "group.com.donghao.TodoLite"
    static let key = "widgetData"

    static func load(from defaults: UserDefaults?, at date: Date = Date(), calendar: Calendar = .current) -> WidgetData {
        guard let data = defaults?.data(forKey: key),
              let snapshot = try? JSONDecoder().decode(WidgetData.self, from: data) else {
            return .empty(at: date, calendar: calendar)
        }
        return snapshot.validSnapshot(at: date, calendar: calendar)
    }

    static func nextDay(after date: Date, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date)) ?? date.addingTimeInterval(86400)
    }
}
