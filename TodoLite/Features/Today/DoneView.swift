import SwiftUI

struct DoneView: View {
    @State private var store = TodoStore.shared
    @State private var selectedWeekForReport: WeekReportSelection?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                if groupedTodos.isEmpty {
                    EmptyStateView(
                        icon: "checkmark.circle",
                        title: "还没有完成的任务",
                        subtitle: "去收件箱或看板开始行动吧"
                    )
                } else {
                    ForEach(groupedTodos) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(group.week.title())
                                    .appFont(.callout, design: .rounded, weight: .semibold)
                                    .foregroundStyle(SectionTheme.done.secondaryText)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(SectionTheme.done.softBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))

                                Spacer()

                                reportButton(for: group)
                            }

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
        .sheet(item: $selectedWeekForReport) { week in
            WeeklyReportSheet(
                week: week.week,
                todos: week.todos,
                projects: store.projects
            )
        }
    }

    private var groupedTodos: [CompletedTodoWeek] {
        CompletedTodoWeek.groups(todos: store.todos)
    }

    private func reportButton(for group: CompletedTodoWeek) -> some View {
        Button {
            selectedWeekForReport = WeekReportSelection(week: group.week, todos: group.todos)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "sparkles")
                    .appFont(.caption)
                Text("生成周报")
                    .appFont(.caption)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(SectionTheme.done.softBackground)
            .foregroundStyle(SectionTheme.done.secondaryText)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    private var horizontalPadding: CGFloat {
        #if os(iOS)
        16
        #else
        12
        #endif
    }
}

struct WeekReportSelection: Identifiable {
    var id: Date { week.start }
    let week: ReportWeek
    let todos: [TodoItem]
}
