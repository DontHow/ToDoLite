import SwiftUI

struct UpcomingView: View {
    @State private var store = TodoStore.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    Text("即将到来")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    ForEach(upcomingTodos) { todo in
                        TodoListCard(todo: todo)
                    }
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, 12)
            }
            .navigationTitle("即将到来")
            .overlay {
                if upcomingTodos.isEmpty {
                    EmptyStateView(
                        icon: "calendar.badge.clock",
                        title: "没有即将到来的任务",
                        subtitle: "未来几天暂无安排"
                    )
                }
            }
        }
    }

    private var upcomingTodos: [TodoItem] {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let tomorrowStart = calendar.date(byAdding: .day, value: 1, to: todayStart)!
        return store.todos
            .filter {
                $0.status != .done && $0.status != .archived &&
                (
                    ($0.scheduledAt.map { $0 >= tomorrowStart } ?? false) ||
                    ($0.dueAt.map { $0 >= tomorrowStart } ?? false)
                )
            }
            .sorted {
                let d0 = $0.scheduledAt ?? $0.dueAt ?? .distantFuture
                let d1 = $1.scheduledAt ?? $1.dueAt ?? .distantFuture
                return d0 < d1
            }
    }

    private var horizontalPadding: CGFloat {
        #if os(iOS)
        16
        #else
        12
        #endif
    }
}
