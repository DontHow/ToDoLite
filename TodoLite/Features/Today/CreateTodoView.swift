import SwiftUI

struct CreateTodoView: View {
    @State private var store = TodoStore.shared
    @State private var title = ""
    @State private var description = ""
    @State private var status: TodoStatus = .inbox
    @State private var priority: TodoPriority = .medium
    @State private var projectId: String?
    @State private var scheduledAt: Date?
    @State private var dueAt: Date?
    @State private var useQuickEntry = false
    @State private var parsedDraft: TodoDraft?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("快速输入", isOn: $useQuickEntry)

                    if useQuickEntry {
                        TextField("例：提交 TestFlight @工作 #iOS !高 ^明天", text: $title)
                            .onChange(of: title) { _, newValue in
                                parsedDraft = TodoParser.parse(newValue)
                            }

                        if let draft = parsedDraft, !draft.title.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("预览")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(draft.title)
                                    .font(.headline)
                                HStack(spacing: 8) {
                                    if let project = draft.projectName {
                                        Text("@" + project)
                                            .font(.caption)
                                            .foregroundStyle(.blue)
                                    }
                                    if let prio = draft.priority {
                                        Text("!" + prio.displayName)
                                            .font(.caption)
                                            .foregroundStyle(.orange)
                                    }
                                    if let date = draft.scheduledAt {
                                        Text("^" + date.formatted(.dateTime.month().day()))
                                            .font(.caption)
                                            .foregroundStyle(.green)
                                    }
                                    ForEach(draft.tagNames, id: \.self) { tag in
                                        Text("#" + tag)
                                            .font(.caption)
                                            .foregroundStyle(.purple)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    } else {
                        TextField("标题", text: $title)
                        TextField("描述", text: $description, axis: .vertical)
                            .lineLimit(3...6)
                    }
                }

                if !useQuickEntry {
                    Section("状态") {
                        Picker("状态", selection: $status) {
                            ForEach(TodoStatus.allCases, id: \.self) { s in
                                Text(s.displayName).tag(s)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    Section("优先级") {
                        Picker("优先级", selection: $priority) {
                            ForEach(TodoPriority.allCases, id: \.self) { p in
                                Text(p.displayName).tag(p)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    Section("项目") {
                        Picker("项目", selection: $projectId) {
                            Text("无").tag(nil as String?)
                            ForEach(store.projects) { project in
                                Text(project.emoji + " " + project.name).tag(project.id as String?)
                            }
                        }
                    }

                    Section("日期") {
                        DatePicker("计划日期", selection: Binding(
                            get: { scheduledAt ?? Date() },
                            set: { scheduledAt = $0 }
                        ), displayedComponents: .date)
                        DatePicker("截止日期", selection: Binding(
                            get: { dueAt ?? Date() },
                            set: { dueAt = $0 }
                        ), displayedComponents: .date)
                    }
                }
            }
            .navigationTitle("新建任务")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        Task {
                            if useQuickEntry, let draft = parsedDraft {
                                let matchedProject = store.projects.first { $0.name == draft.projectName }
                                let matchedTags = store.tags.filter { draft.tagNames.contains($0.name) }
                                try? await store.createTodo(
                                    title: draft.title,
                                    description: description,
                                    status: .inbox,
                                    priority: draft.priority ?? .medium,
                                    projectId: matchedProject?.id,
                                    tagIds: matchedTags.map(\.id),
                                    scheduledAt: draft.scheduledAt,
                                    dueAt: draft.dueAt
                                )
                            } else {
                                try? await store.createTodo(
                                    title: title,
                                    description: description,
                                    status: status,
                                    priority: priority,
                                    projectId: projectId,
                                    scheduledAt: scheduledAt,
                                    dueAt: dueAt
                                )
                            }
                            dismiss()
                        }
                    }
                    .disabled(useQuickEntry ? (parsedDraft?.title.isEmpty ?? true) : title.isEmpty)
                }
            }
        }
    }
}
