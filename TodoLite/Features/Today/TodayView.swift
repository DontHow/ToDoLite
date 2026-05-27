import SwiftUI

struct TodayView: View {
    @State private var store = TodoStore.shared
    @State private var showingCreate = false

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    focusSection
                    suggestedSection
                    overdueSection
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, 12)
            }
            .navigationTitle("今日")
            .overlay {
                if store.focusTodos.isEmpty && store.suggestedTodos.isEmpty && store.overdueTodos.isEmpty {
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
            VStack(alignment: .leading, spacing: 12) {
                Text("Focus")
                    .font(.system(.title3, design: .rounded, weight: .bold))

                ForEach(store.focusTodos) { todo in
                    TodoListCard(todo: todo)
                }
            }
        }
    }

    @ViewBuilder
    private var suggestedSection: some View {
        if !store.suggestedTodos.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Suggested")
                    .font(.system(.title3, design: .rounded, weight: .bold))

                ForEach(store.suggestedTodos, id: \.id) { todo in
                    TodoListCard(todo: todo)
                }
            }
        }
    }

    @ViewBuilder
    private var overdueSection: some View {
        if !store.overdueTodos.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Overdue")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(.red)

                ForEach(store.overdueTodos, id: \.id) { todo in
                    TodoListCard(todo: todo)
                }
            }
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
