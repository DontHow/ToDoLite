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
                                    .font(.system(.callout, design: .rounded, weight: .semibold))
                                    .foregroundStyle(.primary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color(.tertiarySystemFill))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))

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
        let filtered = store.todos.filter { $0.status == .done }
        let doneTodos = filtered.sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
        guard !doneTodos.isEmpty else { return [] }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        var cal = calendar
        cal.firstWeekday = 2
        let currentWeekComponents = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)

        var groups: [(title: String, todos: [TodoItem])] = []
        var currentTitle: String?
        var currentTodos: [TodoItem] = []

        for todo in doneTodos {
            guard let completedAt = todo.completedAt else { continue }
            let completedDay = calendar.startOfDay(for: completedAt)

            let weekComponents = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: completedDay)
            guard let weekStart = cal.date(from: weekComponents),
                  let weekEnd = cal.date(byAdding: .day, value: 6, to: weekStart) else { continue }

            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "zh_CN")
            formatter.dateFormat = "M月d日"
            let weekRange = "\(formatter.string(from: weekStart))-\(formatter.string(from: weekEnd))"

            let isCurrentWeek = weekComponents.yearForWeekOfYear == currentWeekComponents.yearForWeekOfYear
                && weekComponents.weekOfYear == currentWeekComponents.weekOfYear
            let title = isCurrentWeek ? "本周 \(weekRange)" : weekRange

            if title != currentTitle {
                if let t = currentTitle {
                    groups.append((title: t, todos: currentTodos))
                }
                currentTitle = title
                currentTodos = []
            }
            currentTodos.append(todo)
        }

        if let t = currentTitle, !currentTodos.isEmpty {
            groups.append((title: t, todos: currentTodos))
        }

        return groups
    }

    private var horizontalPadding: CGFloat {
        #if os(iOS)
        16
        #else
        12
        #endif
    }
}
