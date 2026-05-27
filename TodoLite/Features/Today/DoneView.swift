import SwiftUI

struct DoneView: View {
    @State private var store = TodoStore.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 24) {
                    Text("已完成")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if groupedTodos.isEmpty {
                        EmptyStateView(
                            icon: "checkmark.circle",
                            title: "还没有完成的任务",
                            subtitle: "去收件箱或看板开始行动吧"
                        )
                    } else {
                        ForEach(groupedTodos, id: \.title) { group in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(group.title)
                                    .font(.system(.title3, design: .rounded, weight: .bold))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 4)

                                LazyVStack(spacing: 8) {
                                    ForEach(group.todos) { todo in
                                        TodoListCard(todo: todo)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, 12)
            }
            .navigationTitle("已完成")
        }
    }

    private var groupedTodos: [(title: String, todos: [TodoItem])] {
        let doneTodos = store.todos.filter { $0.status == .done }
        guard !doneTodos.isEmpty else { return [] }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        var groups: [String: [TodoItem]] = [:]

        for todo in doneTodos {
            guard let completedAt = todo.completedAt else { continue }
            let completedDay = calendar.startOfDay(for: completedAt)

            let key: String
            let sortKey: Int

            if calendar.isDate(completedDay, inSameDayAs: today) {
                key = "今天"
                sortKey = 0
            } else if calendar.isDate(completedDay, inSameDayAs: calendar.date(byAdding: .day, value: -1, to: today)!) {
                key = "昨天"
                sortKey = 1
            } else if calendar.isDate(completedDay, equalTo: today, toGranularity: .weekOfYear) {
                key = "本周"
                sortKey = 2
            } else if let lastWeekStart = calendar.date(byAdding: .day, value: -7, to: today),
                      let lastWeekEnd = calendar.date(byAdding: .day, value: -1, to: today),
                      completedDay >= calendar.startOfDay(for: lastWeekStart) && completedDay <= calendar.startOfDay(for: lastWeekEnd) {
                key = "上周"
                sortKey = 3
            } else {
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "zh_CN")
                formatter.dateFormat = "yyyy年M月"
                key = formatter.string(from: completedDay)
                sortKey = 4 + (calendar.dateComponents([.month], from: completedDay, to: today).month ?? 0)
            }

            groups[key, default: []].append(todo)
        }

        let orderMap: [String: Int] = [
            "今天": 0,
            "昨天": 1,
            "本周": 2,
            "上周": 3,
        ]

        return groups
            .sorted { a, b in
                let orderA = orderMap[a.key] ?? (4 + (a.key.contains("年") ? 100 : 99))
                let orderB = orderMap[b.key] ?? (4 + (b.key.contains("年") ? 100 : 99))
                return orderA < orderB
            }
            .map { (title: $0.key, todos: $0.value.sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }) }
    }

    private var horizontalPadding: CGFloat {
        #if os(iOS)
        16
        #else
        12
        #endif
    }
}
