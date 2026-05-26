import SwiftUI

struct InboxView: View {
    @State private var store = TodoStore.shared
    @State private var showingCreate = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.inboxTodos) { todo in
                    NavigationLink(value: todo) {
                        TodoRowView(todo: todo)
                    }
                }
            }
            .navigationTitle("收件箱")
            .animation(.default, value: store.inboxTodos.map(\.id))
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
