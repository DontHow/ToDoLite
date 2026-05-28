import SwiftUI

struct BoardView: View {
    @State private var store = TodoStore.shared
    @State private var showingCreate = false

    let columns: [TodoStatus] = [.inbox, .doing, .waiting, .done]

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 24) {
                        ForEach(columns, id: \.self) { status in
                            BoardColumnView(
                                status: status,
                                todos: store.todos.filter { $0.status == status }
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

// MARK: - Sort & Group Options

enum BoardSortOption: String, CaseIterable {
    case dueDate = "截止日期"
    case createdDate = "创建日期"
}

enum BoardViewMode: String, CaseIterable {
    case flat = "列表"
    case byProject = "项目"
}

// MARK: - Board Column

struct BoardColumnView: View {
    let status: TodoStatus
    let todos: [TodoItem]
    @State private var store = TodoStore.shared
    @State private var isTargeted = false
    @State private var sortOption: BoardSortOption = .dueDate
    @State private var viewMode: BoardViewMode = .flat

    private var isConfigurable: Bool {
        status != .done
    }

    private var sortedTodos: [TodoItem] {
        switch sortOption {
        case .dueDate:
            return todos.sorted {
                guard let d0 = $0.dueAt else { return false }
                guard let d1 = $1.dueAt else { return true }
                return d0 < d1
            }
        case .createdDate:
            return todos.sorted { $0.createdAt > $1.createdAt }
        }
    }

    private var groupedByProject: [(projectId: String?, projectName: String, todos: [TodoItem])] {
        let sorted = sortedTodos
        let grouped = Dictionary(grouping: sorted) { $0.projectId }

        var result: [(projectId: String?, projectName: String, todos: [TodoItem])] = []

        // Group with project first, sorted by selected sort option
        let withProject = grouped
            .filter { $0.key != nil }
            .sorted { pair0, pair1 in
                switch sortOption {
                case .dueDate:
                    let d0 = pair0.value.compactMap(\.dueAt).min() ?? .distantFuture
                    let d1 = pair1.value.compactMap(\.dueAt).min() ?? .distantFuture
                    return d0 < d1
                case .createdDate:
                    let d0 = pair0.value.map(\.createdAt).max() ?? .distantPast
                    let d1 = pair1.value.map(\.createdAt).max() ?? .distantPast
                    return d0 > d1
                }
            }

        for (pid, ptodos) in withProject {
            let name = store.projects.first(where: { $0.id == pid })?.name ?? "未命名项目"
            result.append((projectId: pid, projectName: name, todos: ptodos))
        }

        // Ungrouped last
        if let ungrouped = grouped[nil], !ungrouped.isEmpty {
            result.append((projectId: nil, projectName: "未分配", todos: ungrouped))
        }

        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Text(status.displayName)
                    .font(.body.weight(.bold))

                Text("\(todos.count)")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(Color.labelSecondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.chipBackground)
                    .clipShape(Capsule())

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            if isConfigurable {
                columnToolbar
            }

            Divider()
                .padding(.horizontal, 12)

            // Cards area
            GeometryReader { scrollGeo in
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: 12) {
                        if todos.isEmpty {
                            emptyPlaceholder
                        } else if viewMode == .byProject && isConfigurable {
                            projectGroupedContent
                        } else {
                            flatContent
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 10)
                }
                .frame(width: 260, height: scrollGeo.size.height)
            }
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isTargeted ? Color.accentColor.opacity(0.06) : Color.clear)
            )
        }
        .frame(maxHeight: .infinity, alignment: .top)
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

    // MARK: - Toolbar

    private var columnToolbar: some View {
        HStack(spacing: 6) {
            Menu {
                ForEach(BoardSortOption.allCases, id: \.self) { option in
                    Button {
                        sortOption = option
                    } label: {
                        HStack {
                            Text(option.rawValue)
                            if sortOption == option {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.caption2)
                    Text(sortOption.rawValue)
                        .font(.caption2)
                }
                .foregroundStyle(Color.labelSecondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.chipBackground)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .menuStyle(.borderlessButton)

            Spacer()

            HStack(spacing: 0) {
                ForEach(BoardViewMode.allCases, id: \.self) { mode in
                    Button {
                        viewMode = mode
                    } label: {
                        Image(systemName: mode == .flat ? "list.bullet" : "folder")
                            .font(.caption2)
                            .foregroundStyle(viewMode == mode ? .primary : Color.labelSecondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(viewMode == mode ? Color(.tertiarySystemFill) : Color.clear)
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(Color.chipBackground)
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 6)
    }

    // MARK: - Content Views

    private var flatContent: some View {
        VStack(spacing: 12) {
            ForEach(sortedTodos) { todo in
                BoardCardView(todo: todo)
                    .transition(.scale.combined(with: .opacity))
            }
        }
    }

    private var projectGroupedContent: some View {
        VStack(spacing: 16) {
            ForEach(groupedByProject, id: \.projectId) { group in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 4) {
                        if group.projectId != nil,
                           let project = store.projects.first(where: { $0.id == group.projectId }) {
                            Text(project.emoji)
                                .font(.callout)
                                .foregroundStyle(Color.accentColor)
                        }
                        Text(group.projectName)
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(Color.accentColor)

                        Text("\(group.todos.count)")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Color.accentColor.opacity(0.7))

                        Spacer()
                    }
                    .padding(.horizontal, 4)

                    VStack(spacing: 8) {
                        ForEach(group.todos) { todo in
                            BoardCardView(todo: todo)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                }
            }
        }
    }

    private var emptyPlaceholder: some View {
        RoundedRectangle(cornerRadius: 8)
            .stroke(Color.separatorColor.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
            .frame(maxWidth: .infinity, minHeight: 48)
            .overlay(
                Text("拖拽任务到此处")
                    .font(.callout)
                    .foregroundStyle(Color.labelSecondary)
            )
    }
}

// MARK: - Board Card

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
                        .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 3)
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
