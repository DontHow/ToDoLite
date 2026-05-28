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

    static func sync(todos: [TodoItem], focusSet: FocusSet) {
        let focusIds = Set(focusSet.taskIds)
        let focusTodos = todos
            .filter { focusIds.contains($0.id) && $0.status != .done && $0.status != .archived }

        let data = WidgetData(
            count: focusTodos.count,
            titles: focusTodos.prefix(3).map(\.title),
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
