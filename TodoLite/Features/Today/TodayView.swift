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
            .navigationDestination(for: TodoItem.self) { todo in
                TodoDetailView(todo: todo)
            }
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
                    NavigationLink(value: todo) {
                        TodoRowView(todo: todo)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            Task { try? await store.removeFromFocus(id: todo.id) }
                        } label: {
                            Label("移除", systemImage: "minus.circle")
                        }
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            Task { try? await store.toggleComplete(id: todo.id) }
                        } label: {
                            let isDone = todo.status == .done
                            Label(isDone ? "未完成" : "完成", systemImage: isDone ? "arrow.uturn.backward.circle" : "checkmark.circle")
                        }
                        .tint(.green)
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
                    NavigationLink(value: todo) {
                        TodoRowView(todo: todo)
                    }
                    .overlay(alignment: .trailing) {
                        Button {
                            Task { try? await store.addToFocus(id: todo.id) }
                        } label: {
                            Image(systemName: "plus.circle")
                                .foregroundStyle(.blue)
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 4)
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
                    NavigationLink(value: todo) {
                        TodoRowView(todo: todo)
                    }
                    .overlay(alignment: .trailing) {
                        Button {
                            Task { try? await store.addToFocus(id: todo.id) }
                        } label: {
                            Image(systemName: "plus.circle")
                                .foregroundStyle(.blue)
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 4)
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
