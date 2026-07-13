import SwiftUI

enum TaskGrouping: String, CaseIterable {
    case none = "默认"
    case dueDate = "截止日期"
    case createdDate = "创建日期"
    case completedDate = "完成日期"
    case byProject = "项目分组"
}

struct TaskGroup: Identifiable {
    let id = UUID()
    let title: String
    let todos: [TodoItem]
}

struct TaskListView: View {
    let title: String
    let todos: [TodoItem]
    var emptyPlaceholder: String? = nil
    var accentColor: Color? = nil
    var accentTheme: SectionTheme? = nil
    var onDrop: ((String) -> Bool)? = nil
    var isDraggable: Bool = false

    @State private var store = TodoStore.shared
    @State private var grouping: TaskGrouping
    @State private var isTargeted = false

    init(
        title: String,
        todos: [TodoItem],
        emptyPlaceholder: String? = nil,
        accentColor: Color? = nil,
        accentTheme: SectionTheme? = nil,
        defaultGrouping: TaskGrouping = .none,
        onDrop: ((String) -> Bool)? = nil,
        isDraggable: Bool = false
    ) {
        self.title = title
        self.todos = todos
        self.emptyPlaceholder = emptyPlaceholder
        self.accentColor = accentColor
        self.accentTheme = accentTheme
        self.onDrop = onDrop
        self.isDraggable = isDraggable
        _grouping = State(initialValue: defaultGrouping)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().padding(.horizontal, 12)
            content
        }
        .background(
            EllipticalGradient(
                gradient: Gradient(stops: [
                    Gradient.Stop(color: Color.cardBackground, location: 0.0),
                    Gradient.Stop(color: Color.cardBackground, location: 0.45),
                    Gradient.Stop(color: (accentTheme?.softBackground ?? Color.cardBackground).opacity(0.55), location: 0.72),
                    Gradient.Stop(color: (accentTheme?.softBackground ?? Color.cardBackground).opacity(0.85), location: 0.86),
                    Gradient.Stop(color: (accentTheme?.primaryText ?? accentColor ?? Color.separatorColor).opacity(0.35), location: 1.0),
                ]),
                center: .center,
                startRadiusFraction: 0,
                endRadiusFraction: 1.2
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(accentTheme?.primaryText ?? accentColor ?? Color.separatorColor, lineWidth: 1.5)
        )
        .dropDestination(for: String.self) { items, location in
            guard let id = items.first, let drop = onDrop else { return false }
            return drop(id)
        } isTargeted: { targeted in
            isTargeted = targeted
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text(title)
                .appFont(.body, weight: .bold)
                .foregroundStyle(accentTheme?.primaryText ?? .primary)

            Text("\(todos.count)")
                .appFont(.callout, weight: .semibold)
                .foregroundStyle(accentTheme?.onBackground ?? .primary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(accentTheme?.background ?? accentColor ?? Color.chipBackground)
                .clipShape(Capsule())

            Spacer()

            Menu {
                ForEach(TaskGrouping.allCases, id: \.self) { option in
                    Button {
                        grouping = option
                    } label: {
                        HStack {
                            Text(option.rawValue)
                            if grouping == option {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.up.arrow.down")
                        .appFont(.caption2)
                    Text(grouping.rawValue)
                        .appFont(.caption2)
                }
                .foregroundStyle(Color.labelSecondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.chipBackground)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .menuStyle(.borderlessButton)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var content: some View {
        Group {
            if todos.isEmpty, let placeholder = emptyPlaceholder {
                emptyView(placeholder)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 10)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(groupedTodos) { group in
                        if grouping != .none {
                            HStack(spacing: 4) {
                                Text(group.title)
                                    .appFont(.callout, weight: .semibold)
                                    .foregroundStyle(accentTheme?.secondaryText ?? Color.accentColor)
                                Spacer()
                            }
                            .padding(.horizontal, 4)
                        }

                        ForEach(group.todos) { todo in
                            TodoListCard(todo: todo, isDraggable: isDraggable)
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 10)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isTargeted ? (accentTheme?.softBackground ?? Color.accentColor.opacity(0.06)) : Color.clear)
        )
    }

    private func emptyView(_ text: String) -> some View {
        RoundedRectangle(cornerRadius: 8)
            .stroke(Color.separatorColor.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
            .frame(maxWidth: .infinity, minHeight: 48)
            .overlay(
                Text(text)
                    .appFont(.callout)
                    .foregroundStyle(Color.labelSecondary)
            )
    }

    private var groupedTodos: [TaskGroup] {
        grouping.apply(to: todos, projects: store.projects)
    }
}

extension TaskGrouping {
    func apply(to todos: [TodoItem], projects: [Project]) -> [TaskGroup] {
        switch self {
        case .none:
            return [TaskGroup(title: rawValue, todos: todos)]
        case .dueDate:
            return groupByDueDate(todos)
        case .createdDate:
            return groupByCreatedDate(todos)
        case .completedDate:
            return groupByCompletedDate(todos)
        case .byProject:
            return groupByProject(todos, projects: projects)
        }
    }

    private func groupByDueDate(_ todos: [TodoItem]) -> [TaskGroup] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        let endOfWeek = calendar.date(byAdding: .day, value: 7, to: today)!

        var todayTodos: [TodoItem] = []
        var tomorrowTodos: [TodoItem] = []
        var overdueTodos: [TodoItem] = []
        var thisWeekTodos: [TodoItem] = []
        var futureTodos: [TodoItem] = []
        var noDueTodos: [TodoItem] = []

        for todo in todos {
            guard let due = todo.dueAt else {
                noDueTodos.append(todo)
                continue
            }
            let dueDay = calendar.startOfDay(for: due)
            if dueDay < today {
                overdueTodos.append(todo)
            } else if dueDay == today {
                todayTodos.append(todo)
            } else if dueDay == tomorrow {
                tomorrowTodos.append(todo)
            } else if dueDay < endOfWeek {
                thisWeekTodos.append(todo)
            } else {
                futureTodos.append(todo)
            }
        }

        var groups: [TaskGroup] = []
        if !overdueTodos.isEmpty { groups.append(TaskGroup(title: "逾期", todos: overdueTodos)) }
        if !todayTodos.isEmpty { groups.append(TaskGroup(title: "今天", todos: todayTodos)) }
        if !tomorrowTodos.isEmpty { groups.append(TaskGroup(title: "明天", todos: tomorrowTodos)) }
        if !thisWeekTodos.isEmpty { groups.append(TaskGroup(title: "本周", todos: thisWeekTodos)) }
        if !futureTodos.isEmpty { groups.append(TaskGroup(title: "未来", todos: futureTodos)) }
        if !noDueTodos.isEmpty { groups.append(TaskGroup(title: "无截止日期", todos: noDueTodos)) }
        return groups
    }

    private func groupByCreatedDate(_ todos: [TodoItem]) -> [TaskGroup] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: today)!
        let monthAgo = calendar.date(byAdding: .month, value: -1, to: today)!

        var todayTodos: [TodoItem] = []
        var thisWeekTodos: [TodoItem] = []
        var thisMonthTodos: [TodoItem] = []
        var earlierTodos: [TodoItem] = []

        for todo in todos {
            let created = todo.createdAt
            if calendar.isDate(created, inSameDayAs: today) {
                todayTodos.append(todo)
            } else if created > weekAgo {
                thisWeekTodos.append(todo)
            } else if created > monthAgo {
                thisMonthTodos.append(todo)
            } else {
                earlierTodos.append(todo)
            }
        }

        var groups: [TaskGroup] = []
        if !todayTodos.isEmpty { groups.append(TaskGroup(title: "今天", todos: todayTodos)) }
        if !thisWeekTodos.isEmpty { groups.append(TaskGroup(title: "本周", todos: thisWeekTodos)) }
        if !thisMonthTodos.isEmpty { groups.append(TaskGroup(title: "本月", todos: thisMonthTodos)) }
        if !earlierTodos.isEmpty { groups.append(TaskGroup(title: "更早", todos: earlierTodos)) }
        return groups
    }

    private func groupByCompletedDate(_ todos: [TodoItem]) -> [TaskGroup] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: today)!
        let twoWeeksAgo = calendar.date(byAdding: .day, value: -14, to: today)!

        var todayTodos: [TodoItem] = []
        var thisWeekTodos: [TodoItem] = []
        var lastWeekTodos: [TodoItem] = []
        var earlierTodos: [TodoItem] = []

        for todo in todos {
            guard let completed = todo.completedAt else { continue }
            let day = calendar.startOfDay(for: completed)
            if day == today {
                todayTodos.append(todo)
            } else if completed > weekAgo {
                thisWeekTodos.append(todo)
            } else if completed > twoWeeksAgo {
                lastWeekTodos.append(todo)
            } else {
                earlierTodos.append(todo)
            }
        }

        var groups: [TaskGroup] = []
        if !todayTodos.isEmpty { groups.append(TaskGroup(title: "今天", todos: todayTodos)) }
        if !thisWeekTodos.isEmpty { groups.append(TaskGroup(title: "本周", todos: thisWeekTodos)) }
        if !lastWeekTodos.isEmpty { groups.append(TaskGroup(title: "上周", todos: lastWeekTodos)) }
        if !earlierTodos.isEmpty { groups.append(TaskGroup(title: "更早", todos: earlierTodos)) }
        return groups
    }

    private func groupByProject(_ todos: [TodoItem], projects: [Project]) -> [TaskGroup] {
        let grouped = Dictionary(grouping: todos) { $0.projectId }

        var groups: [TaskGroup] = []

        let withProject = grouped
            .filter { $0.key != nil }
            .sorted { pair0, pair1 in
                let minDue0 = pair0.value.compactMap { $0.dueAt }.min()
                let minDue1 = pair1.value.compactMap { $0.dueAt }.min()
                if let d0 = minDue0, let d1 = minDue1 { return d0 < d1 }
                return minDue0 != nil
            }

        for (pid, ptodos) in withProject {
            let name = projects.first(where: { $0.id == pid })?.name ?? "未命名项目"
            groups.append(TaskGroup(title: name, todos: ptodos.sorted { a, b in
                if let da = a.dueAt, let db = b.dueAt { return da < db }
                return a.dueAt != nil
            }))
        }

        if let ungrouped = grouped[nil], !ungrouped.isEmpty {
            groups.append(TaskGroup(title: "未分配", todos: ungrouped.sorted { a, b in
                if let da = a.dueAt, let db = b.dueAt { return da < db }
                return a.dueAt != nil
            }))
        }

        return groups
    }
}
