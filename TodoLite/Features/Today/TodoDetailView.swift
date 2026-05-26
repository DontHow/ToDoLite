import SwiftUI

struct TodoDetailView: View {
    let todo: TodoItem
    @State private var store = TodoStore.shared
    @State private var edited: TodoItem
    @Environment(\.dismiss) private var dismiss

    init(todo: TodoItem) {
        self.todo = todo
        _edited = State(initialValue: todo)
    }

    var body: some View {
        Form {
            Section {
                TextField("标题", text: $edited.title)
                TextField("描述", text: $edited.description, axis: .vertical)
                    .lineLimit(3...6)
            }

            Section("状态") {
                Picker("状态", selection: $edited.status) {
                    ForEach(TodoStatus.allCases, id: \.self) { status in
                        Text(status.displayName).tag(status)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("优先级") {
                Picker("优先级", selection: $edited.priority) {
                    ForEach(TodoPriority.allCases, id: \.self) { priority in
                        Text(priority.displayName).tag(priority)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("项目") {
                Picker("项目", selection: $edited.projectId) {
                    Text("无").tag(nil as String?)
                    ForEach(store.projects) { project in
                        Text(project.emoji + " " + project.name).tag(project.id as String?)
                    }
                }
            }

            Section("日期") {
                DatePicker("计划日期", selection: Binding(
                    get: { edited.scheduledAt ?? Date() },
                    set: { edited.scheduledAt = $0 }
                ), displayedComponents: .date)
                DatePicker("截止日期", selection: Binding(
                    get: { edited.dueAt ?? Date() },
                    set: { edited.dueAt = $0 }
                ), displayedComponents: .date)
            }

            Section {
                Toggle("固定到今日", isOn: $edited.isPinnedToday)
            }

            Section {
                Button("保存") {
                    Task {
                        try? await store.updateTodo(edited)
                        dismiss()
                    }
                }
                .frame(maxWidth: .infinity)

                Button("归档") {
                    Task {
                        try? await store.archiveTodo(id: edited.id)
                        dismiss()
                    }
                }
                .foregroundStyle(.orange)
                .frame(maxWidth: .infinity)

                Button("删除") {
                    Task {
                        try? await store.deleteTodo(id: edited.id)
                        dismiss()
                    }
                }
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("编辑")
    }
}
