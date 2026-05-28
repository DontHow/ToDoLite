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
    var onDrop: ((String) -> Bool)? = nil
    var isDraggable: Bool = false

    @State private var store = TodoStore.shared
    @State private var grouping: TaskGrouping = .none
    @State private var isTargeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().padding(.horizontal, 12)
            content
        }
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
                .font(.body.weight(.bold))

            Text("\(todos.count)")
                .font(.callout.weight(.semibold))
                .foregroundStyle(Color.labelSecondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.chipBackground)
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
                        .font(.caption2)
                    Text(grouping.rawValue)
                        .font(.caption2)
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
                                    .font(.callout.weight(.semibold))
                                    .foregroundStyle(Color.accentColor)
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
                .fill(isTargeted ? Color.accentColor.opacity(0.06) : Color.clear)
        )
    }

    private func emptyView(_ text: String) -> some View {
        RoundedRectangle(cornerRadius: 8)
            .stroke(Color.separatorColor.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
            .frame(maxWidth: .infinity, minHeight: 48)
            .overlay(
                Text(text)
                    .font(.callout)
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
        var thisWeekTodos: [TodoItem] = []
        var futureTodos: [TodoItem] = []
        var noDueTodos: [TodoItem] = []

        for todo in todos {
            guard let due = todo.dueAt else {
                noDueTodos.append(todo)
                continue
            }
            let dueDay = calendar.startOfDay(for: due)
            if dueDay == today {
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
                let name0 = projects.first(where: { $0.id == pair0.key })?.name ?? ""
                let name1 = projects.first(where: { $0.id == pair1.key })?.name ?? ""
                return name0 < name1
            }

        for (pid, ptodos) in withProject {
            let name = projects.first(where: { $0.id == pid })?.name ?? "未命名项目"
            groups.append(TaskGroup(title: name, todos: ptodos))
        }

        if let ungrouped = grouped[nil], !ungrouped.isEmpty {
            groups.append(TaskGroup(title: "未分配", todos: ungrouped))
        }

        return groups
    }
}
