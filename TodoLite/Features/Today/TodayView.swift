import SwiftUI

struct TodayView: View {
    @State private var store = TodoStore.shared
    @State private var showingCreate = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.todayTodos) { todo in
                    NavigationLink(value: todo) {
                        TodoRowView(todo: todo)
                    }
                }
                .transition(.slide)
                .animation(.default, value: store.todayTodos.map(\.id))
            }
            .navigationTitle("今日")
            .animation(.default, value: store.todayTodos.map(\.id))
            .overlay {
                if store.todayTodos.isEmpty {
                    EmptyStateView(
                        icon: "sun.max.fill",
                        title: "今日无任务",
                        subtitle: "享受自由的一天，或用 ⌘N 新建任务"
                    )
                }
            }
            .navigationDestination(for: TodoItem.self) { todo in
                TodoDetailView(todo: todo)
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
}
