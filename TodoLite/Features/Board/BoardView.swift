import SwiftUI

struct BoardView: View {
    @State private var store = TodoStore.shared
    @State private var showingCreate = false

    let columns: [TodoStatus] = [.inbox, .doing, .waiting, .done]

    var body: some View {
        NavigationStack {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 24) {
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
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Text(status.displayName)
                    .font(.subheadline.weight(.bold))

                Text("\(todos.count)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.labelSecondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Color.chipBackground)
                    .clipShape(Capsule())

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()
                .padding(.horizontal, 12)

            // Cards area
            VStack(spacing: 12) {
                if todos.isEmpty {
                    emptyPlaceholder
                }

                ForEach(todos) { todo in
                    BoardCardView(todo: todo)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 10)
            .frame(width: 260)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isTargeted ? Color.accentColor.opacity(0.06) : Color.clear)
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

    private var emptyPlaceholder: some View {
        RoundedRectangle(cornerRadius: 8)
            .stroke(Color.separatorColor.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
            .frame(maxWidth: .infinity, minHeight: 48)
            .overlay(
                Text("拖拽任务到此处")
                    .font(.caption)
                    .foregroundStyle(Color.labelSecondary)
            )
    }
}

struct BoardCardView: View {
    let todo: TodoItem

    var body: some View {
        NavigationLink(destination: TodoDetailView(todo: todo)) {
            TodoRowView(todo: todo)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        #if os(iOS)
                        .fill(Color(uiColor: .systemBackground))
                        #else
                        .fill(Color(nsColor: .controlBackgroundColor))
                        #endif
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.separatorColor.opacity(0.5), lineWidth: 0.5)
                )
        }
        .buttonStyle(CardButtonStyle())
        .draggable(todo.id)
    }
}
