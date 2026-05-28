import SwiftUI

struct TodayView: View {
    @State private var store = TodoStore.shared
    @State private var showingCreate = false

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 20) {
                    focusSection
                    suggestedSection
                    overdueSection
                    upcomingSection
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, 12)
            }
            .navigationTitle("今日")
            .overlay {
                if store.focusTodos.isEmpty && store.suggestedTodos.isEmpty && store.overdueTodos.isEmpty && store.upcomingTodos.isEmpty {
                    EmptyStateView(
                        icon: "sun.max.fill",
                        title: "今日无任务",
                        subtitle: "享受自由的一天，或用 ⌘N 新建任务"
                    )
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingCreate = true }) {
                        Image(systemName: "plus")
                    }
                    .keyboardShortcut("n", modifiers: .command)
                }
            }
            .sheet(isPresented: $showingCreate) {
                CreateTodoView()
            }
        }
    }

    @ViewBuilder
    private var focusSection: some View {
        if !store.focusTodos.isEmpty {
            TaskListView(title: "Focus", todos: store.focusTodos)
        }
    }

    @ViewBuilder
    private var suggestedSection: some View {
        if !store.suggestedTodos.isEmpty {
            TaskListView(title: "Suggested", todos: store.suggestedTodos)
        }
    }

    @ViewBuilder
    private var overdueSection: some View {
        if !store.overdueTodos.isEmpty {
            TaskListView(title: "Overdue", todos: store.overdueTodos)
        }
    }

    @ViewBuilder
    private var upcomingSection: some View {
        if !store.upcomingTodos.isEmpty {
            TaskListView(title: "即将到来", todos: store.upcomingTodos)
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
