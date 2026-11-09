import SwiftUI

struct TodoListCard: View {
    let todo: TodoItem
    var isDraggable: Bool = false
    var showsProject: Bool = true
    var todayActions: TodayTaskActions? = nil

    @State private var store = TodoStore.shared
    @State private var isUpdating = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isDraggable {
                row.draggable(todo.id)
            } else {
                row
            }
        }
        .alert("操作失败", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var row: some View {
        HStack(alignment: .center, spacing: 4) {
            if isActive {
                Button {
                    if let todayActions {
                        todayActions.complete(todo)
                    } else {
                        perform { try await store.toggleComplete(id: todo.id) }
                    }
                } label: {
                    controlIcon("circle")
                }
                .buttonStyle(.plain)
                .disabled(isUpdating)
                .accessibilityLabel("标记\(todo.title)为完成")
            } else {
                controlIcon(todo.status == .done ? "checkmark.circle.fill" : "archivebox")
                    .accessibilityHidden(true)
            }

            NavigationLink(destination: CreateTodoView(todo: todo)) {
                TodoRowView(todo: todo, showsProject: showsProject, showsDate: todayActions == nil)
                    .contentShape(Rectangle())
            }
            .buttonStyle(CardButtonStyle())

            if let todayActions {
                dateMenu(todayActions)
            }

            if todo.status != .archived {
                actionsMenu
                    .disabled(isUpdating)
            }
        }
        .padding(.horizontal, 4)
        .background(Color.cardBackgroundTertiary, in: RoundedRectangle(cornerRadius: 8))
    }

    private var actionsMenu: some View {
        Menu {
            if isActive {
                Button {
                    perform {
                        if isFocused {
                            try await store.removeFromFocus(id: todo.id)
                        } else {
                            try await store.addToFocus(id: todo.id)
                        }
                    }
                } label: {
                    Label(isFocused ? "移出今日关注" : "加入今日关注", systemImage: "sun.max")
                }

                if todayActions == nil {
                    rescheduleMenu
                }
            } else {
                Button {
                    perform { try await store.toggleComplete(id: todo.id) }
                } label: {
                    Label("重新打开", systemImage: "arrow.uturn.backward")
                }
            }
        } label: {
            controlIcon("ellipsis")
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .accessibilityLabel("\(todo.title)的更多操作")
    }

    private var rescheduleMenu: some View {
        Menu("重新排期", systemImage: "calendar.badge.clock") {
            ForEach(TodoReschedulePreset.allCases) { preset in
                Button(preset.title) {
                    guard let dueDate = preset.dueDate() else { return }
                    var updated = todo
                    updated.dueAt = dueDate
                    perform { try await store.updateTodo(updated) }
                }
            }
        }
    }

    private func dateMenu(_ actions: TodayTaskActions) -> some View {
        Menu {
            ForEach(["今天", "明天", "下周一"], id: \.self) { title in
                Button(title) {
                    let date = title == "下周一"
                        ? Calendar.current.nextDate(after: Date(), matching: DateComponents(hour: 0, weekday: 2), matchingPolicy: .nextTime)
                        : DateResolver.resolve(title)
                    if let date {
                        actions.reschedule(todo, date)
                    }
                }
            }
            Button("选择日期…") { actions.chooseDate(todo) }
        } label: {
            Text(todo.dueAt.map(todayDateLabel) ?? "设日期")
                .appFont(.caption, weight: .medium)
                .foregroundStyle(Color.labelSecondary)
                .lineLimit(1)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .accessibilityLabel("调整\(todo.title)的截止日期")
    }

    private func controlIcon(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .appFont(.body, weight: .medium)
            .foregroundStyle(todo.status == .done && symbol != "ellipsis" ? Color.green : Color.labelSecondary)
            .frame(minWidth: controlSize, minHeight: controlSize)
            .contentShape(Rectangle())
    }

    private var controlSize: CGFloat {
        #if os(iOS)
        44
        #else
        28
        #endif
    }

    private var isActive: Bool {
        todo.status != .done && todo.status != .archived
    }

    private var isFocused: Bool {
        store.focusSet.taskIds.contains(todo.id)
    }

    private func perform(_ operation: @escaping () async throws -> Void) {
        guard !isUpdating else { return }
        isUpdating = true
        Task {
            defer { isUpdating = false }
            do {
                try await operation()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
