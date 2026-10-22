import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

enum WidgetDataStore {
    static func snapshot(todos: [TodoItem], focusSet: FocusSet, at date: Date = Date()) -> WidgetData {
        guard focusSet.date == WidgetData.dayString(for: date) else { return .empty(at: date) }
        let byID = Dictionary(todos.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var seen = Set<String>()
        let focused = focusSet.taskIds.compactMap { id -> WidgetTask? in
            guard seen.insert(id).inserted, let todo = byID[id], todo.status != .done, todo.status != .archived else { return nil }
            return WidgetTask(id: todo.id, title: todo.title)
        }
        return WidgetData(focusDate: focusSet.date, count: focused.count, tasks: Array(focused.prefix(3)), updatedAt: date)
    }

    static func sync(todos: [TodoItem], focusSet: FocusSet) {
        let data = snapshot(todos: todos, focusSet: focusSet)
        guard let defaults = UserDefaults(suiteName: WidgetSnapshotStore.suiteName) else { return }
        if let saved = defaults.data(forKey: WidgetSnapshotStore.key),
           let previous = try? JSONDecoder().decode(WidgetData.self, from: saved),
           previous.focusDate == data.focusDate, previous.count == data.count, previous.tasks == data.tasks { return }
        guard let encoded = try? JSONEncoder().encode(data) else { return }
        defaults.set(encoded, forKey: WidgetSnapshotStore.key)
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: "TodoLiteWidget")
        #endif
    }
}
