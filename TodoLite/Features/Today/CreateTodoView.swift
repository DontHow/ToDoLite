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
    @State private var hasScheduled = false
    @State private var hasDue = false
    @State private var useQuickEntry = true
    @State private var parsedDraft: TodoDraft?
    @State private var isParsingLLM = false
    @State private var llmError: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: 0) {
                        modeToggle

                        if useQuickEntry {
                            quickEntryArea
                        } else {
                            detailForm
                        }

                        Spacer().frame(height: 100)
                    }
                    .padding(.horizontal, 20)
                }
                .scrollDismissesKeyboard(.interactively)

                saveButtonBar
            }
            .navigationTitle("新建任务")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
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

                if title.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("输入任务...")
                            .foregroundStyle(.tertiary)
                            .font(.title3)
                        Text("@项目 #标签 !优先级 ^日期")
                            .foregroundStyle(.quaternary)
                            .font(.callout)
                    }
                    .padding(20)
                    .allowsHitTesting(false)
                }

                TextEditor(text: $title)
                    .font(.title3)
                    .scrollContentBackground(.hidden)
                    .padding(16)
                    .frame(minHeight: 120)
            }
            .frame(minHeight: 120)
            .onChange(of: title) { _, newValue in
                parsedDraft = TodoParser.parse(newValue)
                llmError = nil
            }

            aiParseButton

            suggestionPanel

            if let draft = parsedDraft, !draft.title.isEmpty {
                quickPreviewCard(draft)
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
                .background(title.isEmpty ? Color.gray : Color.purple)
                .clipShape(Capsule())
            }
            .disabled(title.isEmpty || isParsingLLM)
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
        guard !title.isEmpty else { return }
        let config = store.llmConfig
        guard !config.apiKey.isEmpty else {
            llmError = "请先配置 LLM"
            return
        }

        isParsingLLM = true
        llmError = nil

        do {
            let draft = try await LLMParser.shared.parse(
                title,
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
                    case "!":
                        prioritySuggestions()
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
        let components = title.split(separator: " ", omittingEmptySubsequences: false)
        guard let last = components.last, !last.isEmpty else { return nil }
        let lastStr = String(last)
        guard let first = lastStr.first, ["@", "#", "!", "^"].contains(first) else { return nil }
        return (first, String(lastStr.dropFirst()))
    }

    private func insertSuggestion(_ text: String) {
        let components = title.split(separator: " ", omittingEmptySubsequences: false)
        if components.count > 1 {
            let allButLast = components.dropLast().joined(separator: " ")
            title = allButLast + " " + text
        } else {
            title = text
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

    private func prioritySuggestions() -> some View {
        let options: [(display: String, value: String)] = [
            ("高", "high"), ("中", "medium"), ("低", "low")
        ]
        return suggestionRow(title: "优先级", icon: "flag.fill", color: .orange) {
            ForEach(options, id: \.value) { option in
                suggestionChip(text: option.display) {
                    insertSuggestion("!" + option.value)
                }
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
                    .font(.caption2)
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

                if let prio = draft.priority {
                    TagChip(
                        icon: "flag.fill",
                        text: prio.displayName,
                        color: priorityColor(prio)
                    )
                }

                if let date = draft.scheduledAt {
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
                TextField("任务标题", text: $title)
                    .font(.body.weight(.semibold))

                Divider()

                TextField("添加描述...", text: $description, axis: .vertical)
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

            // Priority
            OptionRow(icon: "flag.fill", iconColor: .orange, label: "优先级") {
                HStack(spacing: 10) {
                    ForEach(TodoPriority.allCases, id: \.self) { p in
                        priorityChip(p)
                    }
                }
            }

            // Project
            OptionRow(icon: "folder.fill", iconColor: .blue, label: "项目") {
                Menu {
                    Button("无项目") { projectId = nil }
                    Divider()
                    ForEach(store.projects) { project in
                        Button {
                            projectId = project.id
                        } label: {
                            HStack {
                                Text(project.emoji + " " + project.name)
                                if projectId == project.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(projectId.flatMap { id in store.projects.first { $0.id == id }?.name } ?? "选择项目")
                            .foregroundStyle(projectId == nil ? Color.labelSecondary : .primary)
                        Image(systemName: "chevron.down")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color.labelSecondary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.chipBackground)
                    .clipShape(Capsule())
                }
            }

            // Dates
            VStack(spacing: 16) {
                dateToggleRow(
                    icon: "calendar",
                    color: .green,
                    label: "计划日期",
                    isOn: $hasScheduled
                )
                if hasScheduled {
                    DatePicker("", selection: Binding(
                        get: { scheduledAt ?? Date() },
                        set: { scheduledAt = $0 }
                    ), displayedComponents: .date)
                    .datePickerStyle(.compact)
                }

                Divider()

                dateToggleRow(
                    icon: "clock.arrow.circlepath",
                    color: .orange,
                    label: "截止日期",
                    isOn: $hasDue
                )
                if hasDue {
                    DatePicker("", selection: Binding(
                        get: { dueAt ?? Date() },
                        set: { dueAt = $0 }
                    ), displayedComponents: .date)
                    .datePickerStyle(.compact)
                }
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.cardBackground)
            )
        }
    }

    private func statusChip(_ s: TodoStatus) -> some View {
        Button {
            withAnimation(.spring(duration: 0.25)) { status = s }
        } label: {
            Text(s.displayName)
                .font(.subheadline.weight(status == s ? .semibold : .regular))
                .foregroundStyle(status == s ? .white : .primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(status == s ? Color.indigo : Color.chipBackground)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func priorityChip(_ p: TodoPriority) -> some View {
        Button {
            withAnimation(.spring(duration: 0.25)) { priority = p }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "flag.fill")
                    .font(.caption2)
                Text(p.displayName)
                    .font(.subheadline.weight(priority == p ? .semibold : .regular))
            }
            .foregroundStyle(priority == p ? .white : priorityColor(p))
            .frame(minWidth: 60)
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(priority == p ? priorityColor(p) : Color.chipBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func dateToggleRow(icon: String, color: Color, label: String, isOn: Binding<Bool>) -> some View {
        HStack {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.body)
                    .symbolRenderingMode(.hierarchical)
                Text(label)
                    .font(.callout)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(color)
        }
    }

    // MARK: - Save Button

    private var saveButtonBar: some View {
        VStack(spacing: 0) {
            Divider()

            Button {
                Task { await save() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                    Text("创建任务")
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
        if useQuickEntry {
            !(parsedDraft?.title.isEmpty ?? true)
        } else {
            !title.isEmpty
        }
    }

    private func priorityColor(_ p: TodoPriority) -> Color {
        switch p {
        case .low: return .gray
        case .medium: return .orange
        case .high: return .red
        }
    }

    private func save() async {
        if useQuickEntry, let draft = parsedDraft {
            let matchedProject = store.projects.first { $0.name == draft.projectName }
            let matchedTags = store.tags.filter { draft.tagNames.contains($0.name) }
            try? await store.createTodo(
                title: draft.title,
                description: draft.description,
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
                scheduledAt: hasScheduled ? scheduledAt : nil,
                dueAt: hasDue ? dueAt : nil
            )
        }
        dismiss()
    }
}
