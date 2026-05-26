import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

struct WidgetData: Codable {
    let count: Int
    let titles: [String]
    let updatedAt: Date
}

enum WidgetDataStore {
    static let suiteName = "group.com.donghao.TodoLite"
    static let key = "widgetData"

    static func sync(todos: [TodoItem]) {
        let today = Calendar.current.startOfDay(for: Date())
        let todayTodos = todos.filter {
            if $0.isPinnedToday { return true }
            guard let scheduled = $0.scheduledAt else { return false }
            return Calendar.current.isDate(scheduled, inSameDayAs: today)
        }

        let data = WidgetData(
            count: todayTodos.count,
            titles: todayTodos.prefix(3).map(\.title),
            updatedAt: Date()
        )

        guard let sharedDefaults = UserDefaults(suiteName: suiteName),
              let encoded = try? JSONEncoder().encode(data) else { return }
        sharedDefaults.set(encoded, forKey: key)

        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: "TodoLiteWidget")
        #endif
    }
}
