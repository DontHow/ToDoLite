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
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, 12)
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

    private var horizontalPadding: CGFloat {
        #if os(iOS)
        16
        #else
        12
        #endif
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
                    .font(.system(.title3, design: .rounded, weight: .bold))
                Spacer()
                Text("\(todos.count)")
                    .font(.caption)
                    .foregroundStyle(Color.labelSecondary)
            }
            .padding(.horizontal, 8)

            VStack(spacing: 8) {
                if todos.isEmpty {
                    Text("拖拽任务到此处")
                        .font(.caption)
                        .foregroundStyle(Color.labelSecondary)
                        .frame(maxWidth: .infinity, minHeight: 60)
                }
                ForEach(todos) { todo in
                    BoardCardView(todo: todo)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(width: 280)
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isTargeted ? Color.accentColor.opacity(0.15) : Color.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.separatorColor.opacity(0.5), lineWidth: 0.5)
            )
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
                .background(Color.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.separatorColor.opacity(0.5), lineWidth: 0.5)
                )
        }
        .buttonStyle(CardButtonStyle())
        .draggable(todo.id)
    }
}
