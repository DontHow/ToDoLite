import SwiftUI

struct TodayView: View {
    @State private var store = TodoStore.shared
    @State private var showingCreate = false

    var body: some View {
        NavigationStack {
            List {
                focusSection
                suggestedSection
                overdueSection
            }
            .listStyle(.plain)
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
            Section {
                ForEach(store.focusTodos) { todo in
                    NavigationLink(destination: TodoDetailView(todo: todo)) {
                        TodoRowView(todo: todo)
                    }
                }
            } header: {
                Text("Focus")
                    .font(.system(.title3, design: .rounded, weight: .bold))
            }
        }
    }

    @ViewBuilder
    private var suggestedSection: some View {
        if !store.suggestedTodos.isEmpty {
            Section {
                ForEach(store.suggestedTodos, id: \.id) { todo in
                    NavigationLink(destination: TodoDetailView(todo: todo)) {
                        TodoRowView(todo: todo)
                    }
                }
            } header: {
                Text("Suggested")
                    .font(.system(.title3, design: .rounded, weight: .bold))
            }
        }
    }

    @ViewBuilder
    private var overdueSection: some View {
        if !store.overdueTodos.isEmpty {
            Section {
                ForEach(store.overdueTodos, id: \.id) { todo in
                    NavigationLink(destination: TodoDetailView(todo: todo)) {
                        TodoRowView(todo: todo)
                    }
                }
            } header: {
                Text("Overdue")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(.red)
            }
        }
    }
}
