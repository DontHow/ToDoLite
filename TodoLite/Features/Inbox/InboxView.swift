import SwiftUI

struct InboxView: View {
    @State private var store = TodoStore.shared
    @State private var showingCreate = false

    var body: some View {
        NavigationStack {
            ScrollView {
                TaskListView(title: "收件箱", todos: store.inboxTodos, accentTheme: .inbox)
                    .padding(.horizontal, horizontalPadding)
                    .padding(.vertical, 12)
            }
            .navigationTitle("收件箱")
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

    private var horizontalPadding: CGFloat {
        #if os(iOS)
        16
        #else
        12
        #endif
    }
}
