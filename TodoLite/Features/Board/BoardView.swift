import SwiftUI

struct BoardView: View {
    @State private var store = TodoStore.shared
    @State private var showingCreate = false
    @State private var selectedColumn: TodoStatus = .inbox
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let columns: [TodoStatus] = [.inbox, .doing, .done]

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                if geo.size.width < 760 || dynamicTypeSize.isAccessibilitySize {
                    VStack(spacing: 12) {
                        if dynamicTypeSize.isAccessibilitySize {
                            statusPicker.pickerStyle(.menu)
                        } else {
                            statusPicker.pickerStyle(.segmented)
                        }
                        BoardColumnView(status: selectedColumn,
                                        todos: store.todos.filter { $0.status == selectedColumn },
                                        columnWidth: max(0, geo.size.width - horizontalPadding * 2),
                                        allowsDragging: false)
                            .id(selectedColumn)
                    }
                    .padding(.horizontal, horizontalPadding)
                    .padding(.vertical, 12)
                } else {
                    let spacing: CGFloat = 24
                    let availableWidth = geo.size.width - horizontalPadding * 2
                    let columnWidth = max(240, (availableWidth - spacing * 2) / 3)
                    ScrollView(.horizontal, showsIndicators: true) {
                        HStack(alignment: .top, spacing: spacing) {
                            ForEach(columns, id: \.self) { status in
                                BoardColumnView(status: status, todos: store.todos.filter { $0.status == status }, columnWidth: columnWidth)
                                    .frame(height: max(0, geo.size.height - 24))
                            }
                        }
                        .padding(.horizontal, horizontalPadding)
                        .padding(.vertical, 12)
                    }
                }
            }
            .navigationTitle("看板")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingCreate = true }) {
                        Image(systemName: "plus")
                    }
                    #if os(iOS)
                    .keyboardShortcut("n", modifiers: .command)
                    #endif
                }
            }
            .navigationDestination(for: TodoItem.self) { todo in
                CreateTodoView(todo: todo)
            }
            .sheet(isPresented: $showingCreate) {
                CreateTodoView()
                    .presentationDetents([.large])
            }
        }
    }

    private var statusPicker: some View {
        Picker("任务状态", selection: $selectedColumn) {
            ForEach(columns, id: \.self) { status in
                Text(status.displayName).tag(status)
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
    var allowsDragging = true
    @State private var store = TodoStore.shared

    var body: some View {
        GeometryReader { geo in
            ScrollView(.vertical, showsIndicators: true) {
                TaskListView(
                    title: status.displayName,
                    todos: todos,
                    emptyPlaceholder: allowsDragging ? "拖拽任务到此处" : "暂无任务",
                    accentTheme: status.theme,
                    defaultGrouping: status == .done ? .byProject : .dueDate,
                    onDrop: dropHandler,
                    isDraggable: allowsDragging
                )
            }
            .frame(height: geo.size.height)
        }
        .frame(width: columnWidth)
    }

    private var dropHandler: ((String) -> Bool)? {
        guard allowsDragging else { return nil }
        return { id in
            guard let todo = store.todos.first(where: { $0.id == id }), todo.status != status else { return false }
            Task {
                do { try await store.changeStatus(id: todo.id, to: status) }
                catch { store.operationError = error.localizedDescription }
            }
            return true
        }
    }
}
