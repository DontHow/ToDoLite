import SwiftUI

struct InboxView: View {
    @State private var store = TodoStore.shared
    @State private var showingCreate = false
    @State private var showingOrganizer = false
    @State private var title = ""
    @State private var saving = false
    @FocusState private var captureFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        TextField("记下一件事，回车保存", text: $title)
                            .textFieldStyle(.roundedBorder)
                            .focused($captureFocused)
                            .onSubmit(capture)
                        Button("收集", action: capture)
                            .buttonStyle(.borderedProminent)
                            .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .disabled(saving)

                    Button {
                        showingOrganizer = true
                    } label: {
                        Label("用 AI 整理", systemImage: "sparkles")
                    }
                    .disabled(store.inboxTodos.isEmpty)

                    if store.inboxTodos.isEmpty {
                        EmptyStateView(icon: "tray", title: "收件箱为空", subtitle: "在上方输入一句话即可收集任务")
                            .frame(maxWidth: .infinity)
                    } else {
                        TaskListView(title: "收件箱", todos: store.inboxTodos, accentTheme: .inbox)
                    }
                }
                .frame(maxWidth: 720)
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("收件箱")
            .sheet(isPresented: $showingOrganizer) {
                InboxOrganizerView(todos: store.inboxTodos)
            }
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
            .sheet(isPresented: $showingCreate) {
                CreateTodoView()
                    .presentationDetents([.large])
            }
        }
    }

    private func capture() {
        let input = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !saving, !input.isEmpty else { return }
        saving = true
        Task {
            defer {
                saving = false
                captureFocused = true
            }
            do {
                try await store.createTodo(title: input)
                title = ""
            } catch {
                store.operationError = error.localizedDescription
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

private struct InboxOrganizerView: View {
    private struct Suggestion: Identifiable {
        let id = UUID().uuidString
        let source: TodoItem
        let draft: TodoDraft
        let updatesSource: Bool
        let matchingTasks: [TodoItem]
        var mergeID: String?
        var accepted = true
        var applied = false
        var error: String?
    }

    let todos: [TodoItem]

    @Environment(\.dismiss) private var dismiss
    @State private var store = TodoStore.shared
    @State private var selected = Set<String>()
    @State private var suggestions: [Suggestion] = []
    @State private var message: String?
    @State private var request: Task<Void, Never>?
    @State private var saving = false

    var body: some View {
        NavigationStack {
            Form {
                if suggestions.isEmpty {
                    Section("选择要整理的记录") {
                        Text("将所选记录的标题、详情以及现有项目和标签名称发送给设置中的模型。")
                            .foregroundStyle(.secondary)
                        ForEach(todos) { todo in
                            Toggle(todo.title, isOn: Binding(
                                get: { selected.contains(todo.id) },
                                set: { if $0 { selected.insert(todo.id) } else { selected.remove(todo.id) } }
                            ))
                            .disabled(request != nil)
                        }
                        Button(request == nil ? "生成整理预览" : "取消生成") {
                            if let request { request.cancel() } else { generate() }
                        }
                        .disabled(selected.isEmpty)
                    }
                } else {
                    ForEach($suggestions) { $item in
                        Section(item.updatesSource ? "更新原任务" : "拆分为新任务 · 保留原记录") {
                            Text("原始记录：\(item.source.title)")
                                .foregroundStyle(.secondary)
                            if !item.source.description.isEmpty {
                                Text(item.source.description).foregroundStyle(.secondary)
                            }
                            Toggle(item.draft.title, isOn: $item.accepted)
                                .disabled(item.applied || saving)
                            if !item.matchingTasks.isEmpty {
                                Picker("整理方式", selection: $item.mergeID) {
                                    Text(item.updatesSource ? "更新原任务" : "创建新任务").tag(nil as String?)
                                    ForEach(item.matchingTasks) { target in
                                        Text("补充到：\(target.title) · \(target.dueAt.map(todayDateLabel) ?? "无截止日期")")
                                            .tag(Optional(target.id))
                                    }
                                }
                                .disabled(item.applied || saving)
                                if item.mergeID != nil {
                                    Text("补充详情并保留原记录。已有项目和日期优先。").foregroundStyle(.secondary)
                                }
                            }
                            if !item.draft.description.isEmpty { Text(item.draft.description) }
                            if let project = item.draft.projectName { Text("项目：\(project)") }
                            if !item.draft.tagNames.isEmpty { Text("标签：\(item.draft.tagNames.joined(separator: "、"))") }
                            if let due = item.draft.dueAt { Text("截止：\(todayDateLabel(due))") }
                            if item.applied { Text("已应用").foregroundStyle(.secondary) }
                            if let error = item.error { Text(error).foregroundStyle(.red) }
                        }
                    }
                    Button("应用所选建议", action: applySelected)
                        .disabled(saving || !suggestions.contains { $0.accepted && !$0.applied })
                }
                if let message { Text(message).foregroundStyle(.secondary) }
            }
            .formStyle(.grouped)
            .navigationTitle("AI 整理收件箱")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }.disabled(saving)
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 540, minHeight: 480)
        #endif
        .interactiveDismissDisabled(saving)
        .onDisappear { request?.cancel() }
    }

    private func generate() {
        let config = store.llmConfig
        guard !config.apiKey.isEmpty else {
            message = "请先在设置中完成 LLM 配置。"
            return
        }
        let sources = todos.filter { selected.contains($0.id) }
        let projects = store.projects
        let tags = store.tags
        let existingTasks = store.todos.filter { !selected.contains($0.id) && ($0.status == .inbox || $0.status == .doing) }
        message = nil
        request = Task {
            defer { request = nil }
            var results: [Suggestion] = []
            var failures: [String] = []
            for source in sources {
                do {
                    let input = [source.title, source.description].filter { !$0.isEmpty }.joined(separator: "\n")
                    let drafts = try await LLMParser.shared.organize(input, projects: projects, tags: tags, config: config)
                    try Task.checkCancellation()
                    results += drafts.map { draft in
                        var matched = draft
                        matched.projectName = projects.first { $0.name == draft.projectName }?.name
                        matched.tagNames = tags.filter { draft.tagNames.contains($0.name) }.map(\.name)
                        let matches = existingTasks.filter {
                            $0.title.trimmingCharacters(in: .whitespacesAndNewlines)
                                .localizedCaseInsensitiveCompare(matched.title.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame
                        }
                        return Suggestion(source: source, draft: matched, updatesSource: drafts.count == 1, matchingTasks: matches)
                    }
                } catch {
                    if Task.isCancelled { return }
                    failures.append(source.title)
                }
            }
            suggestions = results
            if !failures.isEmpty { message = "未能整理：\(failures.joined(separator: "、"))" }
        }
    }

    private func applySelected() {
        guard !saving else { return }
        let merges = suggestions.filter { $0.accepted && !$0.applied }.compactMap(\.mergeID)
        guard Set(merges).count == merges.count else {
            message = "请一次只选择一条建议补充到同一任务。"
            return
        }
        saving = true
        Task {
            defer { saving = false }
            for index in suggestions.indices where suggestions[index].accepted && !suggestions[index].applied {
                let item = suggestions[index]
                let mergeTarget = item.matchingTasks.first { $0.id == item.mergeID }
                var todo = mergeTarget ?? (item.updatesSource ? item.source : TodoItem(id: item.id, title: item.draft.title))
                if mergeTarget != nil {
                    let addition = item.draft.description.isEmpty ? item.source.title : item.draft.description
                    if !todo.description.contains(addition) {
                        todo.description = [todo.description, addition].filter { !$0.isEmpty }.joined(separator: "\n\n")
                    }
                } else {
                    todo.title = item.draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !item.draft.description.isEmpty { todo.description = item.draft.description }
                }
                if todo.dueAt == nil { todo.dueAt = item.draft.dueAt }
                if todo.projectId == nil, let project = store.projects.first(where: { $0.name == item.draft.projectName }) {
                    todo.projectId = project.id
                }
                let suggestedTags = store.tags.filter { item.draft.tagNames.contains($0.name) }.map(\.id)
                todo.tagIds += suggestedTags.filter { !todo.tagIds.contains($0) }
                do {
                    if item.updatesSource || mergeTarget != nil {
                        try await store.updateTodo(todo)
                    } else {
                        try await store.saveDraft(todo, creating: true)
                    }
                    suggestions[index].applied = true
                    suggestions[index].error = nil
                } catch {
                    suggestions[index].error = error.localizedDescription
                }
            }
        }
    }
}
