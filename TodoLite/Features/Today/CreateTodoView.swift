import SwiftUI

private func defaultDueDate() -> Date {
    var calendar = Calendar.current
    var date = Date()
    var weekdaysAdded = 0
    while weekdaysAdded < 3 {
        date = calendar.date(byAdding: .day, value: 1, to: date)!
        let weekday = calendar.component(.weekday, from: date)
        if weekday != 1 && weekday != 7 {
            weekdaysAdded += 1
        }
    }
    return date
}

struct CreateTodoView: View {
    let todo: TodoItem?

    @State private var store = TodoStore.shared
    @State private var edited: TodoItem
    @State private var useQuickEntry = true
    @State private var parsedDraft: TodoDraft?
    @State private var isParsingLLM = false
    @State private var llmError: String?
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss
    @FocusState private var quickEntryFocused: Bool
    @FocusState private var detailTitleFocused: Bool

    init(todo: TodoItem? = nil) {
        self.todo = todo
        if let todo = todo {
            _edited = State(initialValue: todo)
            _useQuickEntry = State(initialValue: false)
        } else {
            var newTodo = TodoItem(title: "")
            newTodo.dueAt = defaultDueDate()
            _edited = State(initialValue: newTodo)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: 0) {
                        if todo == nil {
                            modeToggle
                        }

                        if todo == nil && useQuickEntry {
                            quickEntryArea
                        } else {
                            detailForm
                        }

                        if todo != nil {
                            actionCard
                        }

                        Spacer().frame(height: 100)
                    }
                    .padding(.horizontal, 20)
                }
                .scrollDismissesKeyboard(.interactively)

                saveButtonBar
            }
            .navigationTitle(todo == nil ? "新建任务" : "编辑任务")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .alert("错误", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: - Mode Toggle

    private var modeToggle: some View {
        HStack(spacing: 0) {
            modeButton("快速输入", icon: "bolt.fill", isActive: useQuickEntry) {
                withAnimation(.spring(duration: 0.3)) { useQuickEntry = true }
            }
            modeButton("详细输入", icon: "slider.horizontal.3", isActive: !useQuickEntry) {
                withAnimation(.spring(duration: 0.3)) { useQuickEntry = false }
            }
        }
        .background(Color.chipBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.top, 16)
        .padding(.bottom, 20)
    }

    private func modeButton(_ label: String, icon: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.subheadline)
                Text(label)
                    .font(.subheadline.weight(isActive ? .semibold : .regular))
            }
            .foregroundStyle(isActive ? .white : .primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isActive ? Color.accentColor : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Quick Entry

    private var quickEntryArea: some View {
        VStack(spacing: 16) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.cardBackground)

                if edited.title.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("输入任务...")
                            .foregroundStyle(.tertiary)
                            .font(.title3)
                        Text("@项目 #标签 ^日期")
                            .foregroundStyle(.quaternary)
                            .font(.callout)
                    }
                    .padding(20)
                    .allowsHitTesting(false)
                }

                TextEditor(text: $edited.title)
                    .font(.title3)
                    .scrollContentBackground(.hidden)
                    .padding(16)
                    .frame(minHeight: 120)
                    .focused($quickEntryFocused)
            }
            .frame(minHeight: 120)
            .onChange(of: edited.title) { _, newValue in
                parsedDraft = TodoParser.parse(newValue)
                llmError = nil
            }

            aiParseButton

            suggestionPanel

            if let draft = parsedDraft, !draft.title.isEmpty {
                quickPreviewCard(draft)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                quickEntryFocused = true
            }
        }
    }

    private var aiParseButton: some View {
        HStack(spacing: 12) {
            Button {
                Task { await parseWithLLM() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.subheadline)
                    if isParsingLLM {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("AI 解析")
                            .font(.subheadline.weight(.medium))
                    }
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(edited.title.isEmpty ? Color.gray : Color.purple)
                .clipShape(Capsule())
            }
            .disabled(edited.title.isEmpty || isParsingLLM)
            .buttonStyle(.plain)

            if let error = llmError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(1)
            }

            Spacer()
        }
    }

    private func parseWithLLM() async {
        guard !edited.title.isEmpty else { return }
        let config = store.llmConfig
        guard !config.apiKey.isEmpty else {
            llmError = "请先配置 LLM"
            return
        }

        isParsingLLM = true
        llmError = nil

        do {
            let draft = try await LLMParser.shared.parse(
                edited.title,
                projects: store.projects,
                tags: store.tags,
                config: config
            )
            parsedDraft = draft
        } catch {
            llmError = "解析失败"
        }

        isParsingLLM = false
    }

    private var suggestionPanel: some View {
        Group {
            if let token = activeToken {
                VStack(alignment: .leading, spacing: 10) {
                    switch token.prefix {
                    case "@":
                        projectSuggestions(query: token.query)
                    case "#":
                        tagSuggestions(query: token.query)
                    case "^":
                        dateSuggestions()
                    default:
                        EmptyView()
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.cardBackgroundTertiary)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.accentColor.opacity(0.15), lineWidth: 1)
                )
            }
        }
    }

    private var activeToken: (prefix: Character, query: String)? {
        let components = edited.title.split(separator: " ", omittingEmptySubsequences: false)
        guard let last = components.last, !last.isEmpty else { return nil }
        let lastStr = String(last)
        guard let first = lastStr.first, ["@", "#", "^"].contains(first) else { return nil }
        return (first, String(lastStr.dropFirst()))
    }

    private func insertSuggestion(_ text: String) {
        let components = edited.title.split(separator: " ", omittingEmptySubsequences: false)
        if components.count > 1 {
            let allButLast = components.dropLast().joined(separator: " ")
            edited.title = allButLast + " " + text
        } else {
            edited.title = text
        }
    }

    private func projectSuggestions(query: String) -> some View {
        let filtered = query.isEmpty
            ? store.projects
            : store.projects.filter { $0.name.localizedCaseInsensitiveContains(query) }
        return suggestionRow(title: "项目", icon: "folder.fill", color: .blue) {
            ForEach(filtered) { project in
                suggestionChip(text: project.emoji + " " + project.name) {
                    insertSuggestion("@" + project.name)
                }
            }
            if filtered.isEmpty {
                Text("无匹配项目")
                    .font(.caption)
                    .foregroundStyle(Color.labelSecondary)
                    .padding(.vertical, 4)
            }
        }
    }

    private func tagSuggestions(query: String) -> some View {
        let filtered = query.isEmpty
            ? store.tags
            : store.tags.filter { $0.name.localizedCaseInsensitiveContains(query) }
        return suggestionRow(title: "标签", icon: "number", color: .purple) {
            ForEach(filtered) { tag in
                suggestionChip(text: tag.name) {
                    insertSuggestion("#" + tag.name)
                }
            }
            if filtered.isEmpty {
                Text("无匹配标签")
                    .font(.caption)
                    .foregroundStyle(Color.labelSecondary)
                    .padding(.vertical, 4)
            }
        }
    }

    private func dateSuggestions() -> some View {
        let options: [(display: String, value: String)] = [
            ("今天", "today"), ("明天", "tomorrow"), ("下周", "next week"),
            ("周末", "weekend"), ("周一", "mon"), ("周二", "tue"),
            ("周三", "wed"), ("周四", "thu"), ("周五", "fri")
        ]
        return suggestionRow(title: "日期", icon: "calendar", color: .green) {
            ForEach(options, id: \.value) { option in
                suggestionChip(text: option.display) {
                    insertSuggestion("^" + option.value)
                }
            }
        }
    }

    private func suggestionRow<Content: View>(title: String, icon: String, color: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(color)
                    .symbolRenderingMode(.hierarchical)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.labelSecondary)
            }
            FlowLayout(spacing: 8) {
                content()
            }
        }
    }

    private func suggestionChip(text: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color.chipBackground)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func quickPreviewCard(_ draft: TodoDraft) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(draft.title)
                .font(.headline)
                .foregroundStyle(.primary)

            FlowLayout(spacing: 8) {
                if let project = draft.projectName {
                    TagChip(
                        icon: "folder.fill",
                        text: project,
                        color: .blue
                    )
                }

                if let date = draft.dueAt {
                    TagChip(
                        icon: "calendar",
                        text: date.formatted(.dateTime.month().day()),
                        color: .green
                    )
                }

                ForEach(draft.tagNames, id: \.self) { tag in
                    TagChip(
                        icon: "number",
                        text: tag,
                        color: .purple
                    )
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.cardBackgroundTertiary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.accentColor.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Detail Form

    private var detailForm: some View {
        VStack(spacing: 24) {
            // Title
            VStack(alignment: .leading, spacing: 12) {
                TextField("任务标题", text: $edited.title)
                    .font(.body.weight(.semibold))
                    .focused($detailTitleFocused)

                Divider()

                TextField("添加描述...", text: $edited.description, axis: .vertical)
                    .lineLimit(2...4)
                    .font(.callout)
                    .foregroundStyle(Color.labelSecondary)
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.cardBackground)
            )

            // Status
            OptionRow(icon: "list.bullet.rectangle", iconColor: .indigo, label: "状态") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(TodoStatus.allCases.filter { $0 != .archived }, id: \.self) { s in
                            statusChip(s)
                        }
                    }
                }
            }

            // Project
            OptionRow(icon: "folder.fill", iconColor: .blue, label: "项目") {
                FlowLayout(spacing: 8) {
                    projectChip(nil)
                    ForEach(store.projects) { project in
                        projectChip(project)
                    }
                }
            }

            // Due Date
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundStyle(.orange)
                        .font(.body)
                        .symbolRenderingMode(.hierarchical)
                    Text("截止日期")
                        .font(.body)
                }
                DatePicker("", selection: Binding(
                    get: { edited.dueAt ?? Date() },
                    set: { edited.dueAt = $0 }
                ), displayedComponents: .date)
                .datePickerStyle(.graphical)
                .frame(maxWidth: .infinity)

                if let completedAt = edited.completedAt {
                    Divider()
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.body)
                            .symbolRenderingMode(.hierarchical)
                        Text("完成于 \(completedAt.formatted(.dateTime.year().month().day().hour().minute()))")
                            .font(.body)
                            .foregroundStyle(Color.labelSecondary)
                        Spacer()
                    }
                }
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.cardBackground)
            )
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                detailTitleFocused = true
            }
        }
    }

    private func statusChip(_ s: TodoStatus) -> some View {
        Button {
            withAnimation(.spring(duration: 0.25)) { edited.status = s }
        } label: {
            Text(s.displayName)
                .font(.subheadline.weight(edited.status == s ? .semibold : .regular))
                .foregroundStyle(.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(edited.status == s ? s.color : Color.chipBackground)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func projectChip(_ project: Project?) -> some View {
        let isSelected = edited.projectId == project?.id
        return Button {
            edited.projectId = project?.id
        } label: {
            Text(project.map { $0.emoji + " " + $0.name } ?? "无项目")
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue.opacity(0.2) : Color.chipBackground)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Action Card (Edit only)

    private var actionCard: some View {
        VStack(spacing: 12) {
            Button {
                Task {
                    do {
                        try await store.archiveTodo(id: edited.id)
                        dismiss()
                    } catch {
                        errorMessage = "归档失败: \(error.localizedDescription)"
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "archivebox.fill")
                        .font(.body)
                        .symbolRenderingMode(.hierarchical)
                    Text("归档任务")
                        .font(.body.weight(.medium))
                    Spacer()
                }
                .foregroundStyle(.orange)
            }
            .buttonStyle(.plain)

            Divider()

            Button {
                Task {
                    do {
                        try await store.deleteTodo(id: edited.id)
                        dismiss()
                    } catch {
                        errorMessage = "删除失败: \(error.localizedDescription)"
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "trash.fill")
                        .font(.body)
                        .symbolRenderingMode(.hierarchical)
                    Text("删除任务")
                        .font(.body.weight(.medium))
                    Spacer()
                }
                .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.cardBackground)
        )
    }

    // MARK: - Save Button

    private var saveButtonBar: some View {
        VStack(spacing: 0) {
            Divider()

            Button {
                Task { await save() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: todo == nil ? "plus.circle.fill" : "checkmark.circle.fill")
                        .font(.title3)
                    Text(todo == nil ? "创建任务" : "保存")
                        .font(.headline)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    canSave ? Color.accentColor : Color.gray
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .disabled(!canSave)
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
        }
    }

    // MARK: - Helpers

    private var canSave: Bool {
        if todo == nil && useQuickEntry {
            !(parsedDraft?.title.isEmpty ?? true)
        } else {
            !edited.title.isEmpty
        }
    }

    private func save() async {
        if todo != nil {
            do {
                try await store.updateTodo(edited)
                dismiss()
            } catch {
                errorMessage = "保存失败: \(error.localizedDescription)"
            }
        } else if useQuickEntry, let draft = parsedDraft {
            try? await store.createTodoWithParsed(
                title: draft.title,
                description: draft.description,
                status: .inbox,
                projectName: draft.projectName,
                tagNames: draft.tagNames,
                dueAt: draft.dueAt ?? defaultDueDate()
            )
            dismiss()
        } else {
            try? await store.createTodo(
                title: edited.title,
                description: edited.description,
                status: edited.status,
                projectId: edited.projectId,
                dueAt: edited.dueAt
            )
            dismiss()
        }
    }
}
