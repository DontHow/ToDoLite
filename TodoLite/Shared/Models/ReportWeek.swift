import Foundation

struct ReportWeek: Hashable, Sendable {
    let start: Date
    let end: Date

    init(containing date: Date, calendar: Calendar = .current) {
        var calendar = calendar
        calendar.firstWeekday = 2
        let interval = calendar.dateInterval(of: .weekOfYear, for: date)
        start = interval?.start ?? calendar.startOfDay(for: date)
        end = interval?.end ?? calendar.date(byAdding: .day, value: 7, to: start) ?? start.addingTimeInterval(7 * 86400)
    }

    func contains(_ date: Date) -> Bool { date >= start && date < end }

    func title(now: Date = Date(), calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = calendar.timeZone
        let lastDay = end.addingTimeInterval(-1)
        let currentYear = calendar.component(.year, from: now)
        formatter.dateFormat = calendar.component(.year, from: start) == currentYear
            && calendar.component(.year, from: lastDay) == currentYear ? "M月d日" : "yyyy年M月d日"
        let range = formatter.string(from: start) + "–" + formatter.string(from: lastDay)
        return Self(containing: now, calendar: calendar).start == start ? "本周 " + range : range
    }
}

struct CompletedTodoWeek: Identifiable {
    let week: ReportWeek
    let todos: [TodoItem]
    var id: Date { week.start }

    static func groups(todos: [TodoItem], calendar: Calendar = .current) -> [CompletedTodoWeek] {
        let completed = todos.filter { $0.status == .done && $0.completedAt != nil }
        let groups = Dictionary(grouping: completed) { ReportWeek(containing: $0.completedAt!, calendar: calendar) }
        return groups.map { CompletedTodoWeek(week: $0.key, todos: $0.value.sorted { $0.completedAt! > $1.completedAt! }) }
            .sorted { $0.week.start > $1.week.start }
    }
}
