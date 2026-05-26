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
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                modeSection

                if useQuickEntry {
                    quickEntrySection
                } else {
                    detailSection
                    statusSection
                    prioritySection
                    projectSection
                    dateSection
                }

                saveButtonSection
            }
            .navigationTitle("新建任务")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }

    // MARK: - Mode Toggle

    private var modeSection: some View {
        Section {
            Picker("输入模式", selection: $useQuickEntry) {
                Text("快速输入").tag(true)
                Text("详细输入").tag(false)
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
        }
    }

    // MARK: - Quick Entry

    private var quickEntrySection: some View {
        Section {
            TextField("", text: $title, axis: .vertical)
                .lineLimit(1...3)
                .font(.title3)
                .placeholder(when: title.isEmpty) {
                    Text("提交 TestFlight @工作 #iOS !高 ^明天")
                        .foregroundStyle(.tertiary)
                }
                .onChange(of: title) { _, newValue in
                    parsedDraft = TodoParser.parse(newValue)
                }

            if let draft = parsedDraft, !draft.title.isEmpty {
                draftPreviewCard(draft)
            }
        }
    }

    private func draftPreviewCard(_ draft: TodoDraft) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(draft.title)
                .font(.headline)

            FlowLayout(spacing: 6) {
                if let project = draft.projectName {
                    Label(project, systemImage: "folder")
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.gradient)
                        .clipShape(Capsule())
                }

                if let prio = draft.priority {
                    Label(prio.displayName, systemImage: "flag")
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(priorityColor(prio).gradient)
                        .clipShape(Capsule())
                }

                if let date = draft.scheduledAt {
                    Label(date.formatted(.dateTime.month().day()), systemImage: "calendar")
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.gradient)
                        .clipShape(Capsule())
                }

                ForEach(draft.tagNames, id: \.self) { tag in
                    Label(tag, systemImage: "number")
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.purple.gradient)
                        .clipShape(Capsule())
                }
            }
        }
        .padding()
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
    }

    // MARK: - Detail

    private var detailSection: some View {
        Section {
            TextField("标题", text: $title)
                .font(.title3.weight(.medium))
            TextField("添加描述...", text: $description, axis: .vertical)
                .lineLimit(2...6)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Status

    private var statusSection: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(TodoStatus.allCases, id: \.self) { s in
                        Button {
                            status = s
                        } label: {
                            Text(s.displayName)
                                .font(.subheadline.weight(status == s ? .semibold : .regular))
                                .foregroundStyle(status == s ? .white : .primary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(status == s ? Color.accentColor : Color(.tertiarySystemFill))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
        } header: {
            Label("状态", systemImage: "list.bullet.rectangle")
        }
    }

    // MARK: - Priority

    private var prioritySection: some View {
        Section {
            HStack(spacing: 12) {
                ForEach(TodoPriority.allCases, id: \.self) { p in
                    Button {
                        priority = p
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "flag.fill")
                                .font(.caption)
                            Text(p.displayName)
                                .font(.subheadline.weight(priority == p ? .semibold : .regular))
                        }
                        .foregroundStyle(priority == p ? .white : priorityColor(p))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(priority == p ? priorityColor(p) : Color(.tertiarySystemFill))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
        } header: {
            Label("优先级", systemImage: "flag")
        }
    }

    // MARK: - Project

    private var projectSection: some View {
        Section {
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
                HStack {
                    Image(systemName: "folder")
                        .foregroundStyle(.blue)
                    Text(projectId.flatMap { id in store.projects.first { $0.id == id }?.name } ?? "选择项目")
                        .foregroundStyle(projectId == nil ? .secondary : .primary)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Label("项目", systemImage: "folder")
        }
    }

    // MARK: - Date

    private var dateSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: $hasScheduled) {
                    Label("计划日期", systemImage: "calendar")
                }
                .tint(.green)
                if hasScheduled {
                    DatePicker("", selection: Binding(
                        get: { scheduledAt ?? Date() },
                        set: { scheduledAt = $0 }
                    ), displayedComponents: .date)
                    .datePickerStyle(.graphical)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: $hasDue) {
                    Label("截止日期", systemImage: "clock.arrow.circlepath")
                }
                .tint(.orange)
                if hasDue {
                    DatePicker("", selection: Binding(
                        get: { dueAt ?? Date() },
                        set: { dueAt = $0 }
                    ), displayedComponents: .date)
                    .datePickerStyle(.graphical)
                }
            }
        } header: {
            Label("日期", systemImage: "calendar.badge.clock")
        }
    }

    private var cardBackground: Color {
        #if os(iOS)
        return Color(.secondarySystemBackground)
        #else
        return Color.gray.opacity(0.12)
        #endif
    }

    // MARK: - Save Button

    private var saveButtonSection: some View {
        Section {
            Button {
                Task { await save() }
            } label: {
                HStack {
                    Spacer()
                    Text("创建任务")
                        .font(.headline)
                    Spacer()
                }
            }
            .disabled(!canSave)
            .foregroundStyle(.white)
            .padding(.vertical, 6)
            .background(canSave ? Color.accentColor : Color.gray)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
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
                scheduledAt: hasScheduled ? scheduledAt : nil,
                dueAt: hasDue ? dueAt : nil
            )
        }
        dismiss()
    }
}

// MARK: - Placeholder Modifier

private extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content
    ) -> some View {
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

// MARK: - Flow Layout

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                      y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }

    private struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }
                positions.append(CGPoint(x: x, y: y))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
            }

            self.size = CGSize(width: maxWidth, height: y + lineHeight)
        }
    }
}
