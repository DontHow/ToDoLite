import SwiftUI

struct InboxView: View {
    @State private var store = TodoStore.shared
    @State private var showingCreate = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.inboxTodos) { todo in
                    NavigationLink(destination: TodoDetailView(todo: todo)) {
                        TodoRowView(todo: todo)
                    }
                }
                .transition(.slide)
                .animation(.default, value: store.inboxTodos.map(\.id))
            }
            .navigationTitle("收件箱")
            .animation(.default, value: store.inboxTodos.map(\.id))
            .overlay {
                if store.inboxTodos.isEmpty {
                    EmptyStateView(
                        icon: "tray.fill",
                        title: "收件箱为空",
                        subtitle: "新任务会出现在这里"
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
}
