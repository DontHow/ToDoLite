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
            }
            .navigationTitle("今日")
            .animation(.default, value: store.todayTodos.map(\.id))
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
