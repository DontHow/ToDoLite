import SwiftUI

struct BoardView: View {
    @State private var store = TodoStore.shared
    @State private var showingCreate = false

    let columns: [TodoStatus] = [.inbox, .doing, .waiting, .done]

    var body: some View {
        NavigationStack {
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 16) {
                    ForEach(columns, id: \.self) { status in
                        BoardColumnView(
                            status: status,
                            todos: store.todos.filter { $0.status == status }
                        )
                    }
                }
                .padding()
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
                TodoDetailView(todo: todo)
            }
            .sheet(isPresented: $showingCreate) {
                CreateTodoView()
            }
        }
    }
}

struct BoardColumnView: View {
    let status: TodoStatus
    let todos: [TodoItem]
    @State private var store = TodoStore.shared
    @State private var isTargeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(status.displayName)
                    .font(.headline)
                Spacer()
                Text("\(todos.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)

            VStack(spacing: 8) {
                if todos.isEmpty {
                    Text("拖拽任务到此处")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 60)
                }
                ForEach(todos) { todo in
                    BoardCardView(todo: todo)
                        .transition(.scale.combined(with: .opacity))
                }
                .animation(.default, value: todos.map(\.id))
            }
            .frame(width: 280)
            .padding(8)
            .background(isTargeted ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .dropDestination(for: String.self) { items, location in
            guard let id = items.first,
                  let todo = store.todos.first(where: { $0.id == id }),
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
        } isTargeted: { targeted in
            isTargeted = targeted
        }
    }
}

struct BoardCardView: View {
    let todo: TodoItem

    var body: some View {
        NavigationLink(destination: TodoDetailView(todo: todo)) {
            TodoRowView(todo: todo)
                .padding(8)
                #if os(iOS)
                .background(Color(.systemBackground))
                #else
                .background(Color.white)
                #endif
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .draggable(todo.id)
    }
}
