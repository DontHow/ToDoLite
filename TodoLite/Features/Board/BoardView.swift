import SwiftUI

struct BoardView: View {
    @State private var store = TodoStore.shared
    @State private var showingCreate = false

    let columns: [TodoStatus] = [.inbox, .doing, .done]

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let spacing: CGFloat = 24
                let columnCount = CGFloat(columns.count)
                let availableWidth = geo.size.width - horizontalPadding * 2
                let columnWidth = (availableWidth - spacing * (columnCount - 1)) / columnCount
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: spacing) {
                        ForEach(columns, id: \.self) { status in
                            BoardColumnView(
                                status: status,
                                todos: store.todos.filter { $0.status == status },
                                columnWidth: columnWidth
                            )
                            .frame(height: max(0, geo.size.height - 16))
                        }
                    }
                    .padding(.horizontal, horizontalPadding)
                    .padding(.vertical, 12)
                }
            }
            .navigationTitle("看板")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingCreate = true }) {
                        Image(systemName: "plus")
                    }
                    .keyboardShortcut("n", modifiers: .command)
                }
            }
            .navigationDestination(for: TodoItem.self) { todo in
                CreateTodoView(todo: todo)
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

// MARK: - Board Column

struct BoardColumnView: View {
    let status: TodoStatus
    let todos: [TodoItem]
    let columnWidth: CGFloat
    @State private var store = TodoStore.shared

    var body: some View {
        GeometryReader { geo in
            ScrollView(.vertical, showsIndicators: true) {
                TaskListView(
                    title: status.displayName,
                    todos: todos,
                    emptyPlaceholder: "拖拽任务到此处",
                    accentTheme: status.theme,
                    defaultGrouping: status == .done ? .byProject : .dueDate,
                    onDrop: { id in
                        guard let todo = store.todos.first(where: { $0.id == id }),
                              todo.status != status else { return false }
                        Task {
                            var updated = todo
                            updated.status = status
                            if status == .done {
                                updated.completedAt = Date()
                            } else {
                                updated.completedAt = nil
                            }
                            try? await store.updateTodo(updated)
                        }
                        return true
                    },
                    isDraggable: true
                )
            }
            .frame(height: geo.size.height)
        }
        .frame(width: columnWidth)
    }
}
