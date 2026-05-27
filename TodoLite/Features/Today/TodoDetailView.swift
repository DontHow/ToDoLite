import SwiftUI

struct TodoDetailView: View {
    let todo: TodoItem
    @State private var store = TodoStore.shared
    @State private var edited: TodoItem
    @State private var hasScheduled: Bool
    @State private var hasDue: Bool
    @Environment(\.dismiss) private var dismiss

    init(todo: TodoItem) {
        self.todo = todo
        _edited = State(initialValue: todo)
        _hasScheduled = State(initialValue: todo.scheduledAt != nil)
        _hasDue = State(initialValue: todo.dueAt != nil)
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: 20) {
                        titleCard
                        statusSection
                        prioritySection
                        projectSection
                        tagSection
                        dateCard
                        actionCard

                        Spacer().frame(height: 100)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
                .scrollDismissesKeyboard(.interactively)

                saveButtonBar
            }
            .navigationTitle("编辑任务")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .onChange(of: hasScheduled) { _, newValue in
                if !newValue {
                    edited.scheduledAt = nil
                } else if edited.scheduledAt == nil {
                    edited.scheduledAt = Date()
                }
            }
            .onChange(of: hasDue) { _, newValue in
                if !newValue {
                    edited.dueAt = nil
                } else if edited.dueAt == nil {
                    edited.dueAt = Date()
                }
            }
        }
    }

    // MARK: - Title Card

    private var titleCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("任务标题", text: $edited.title)
                .font(.title2.weight(.semibold))

            Divider()

            TextField("添加描述...", text: $edited.description, axis: .vertical)
                .lineLimit(2...6)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(cardBg)
        )
    }

    // MARK: - Status

    private var statusSection: some View {
        OptionRow(icon: "list.bullet.rectangle", iconColor: .indigo, label: "状态") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(TodoStatus.allCases.filter { $0 != .archived }, id: \.self) { s in
                        statusChip(s)
                    }
                }
            }
        }
    }

    private func statusChip(_ s: TodoStatus) -> some View {
        Button {
            withAnimation(.spring(duration: 0.25)) { edited.status = s }
        } label: {
            Text(s.displayName)
                .font(.subheadline.weight(edited.status == s ? .semibold : .regular))
                .foregroundStyle(edited.status == s ? .white : .primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(edited.status == s ? Color.indigo : chipBg)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Priority

    private var prioritySection: some View {
        OptionRow(icon: "flag.fill", iconColor: .orange, label: "优先级") {
            HStack(spacing: 10) {
                ForEach(TodoPriority.allCases, id: \.self) { p in
                    priorityChip(p)
                }
            }
        }
    }

    private func priorityChip(_ p: TodoPriority) -> some View {
        Button {
            withAnimation(.spring(duration: 0.25)) { edited.priority = p }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "flag.fill")
                    .font(.caption2)
                Text(p.displayName)
                    .font(.subheadline.weight(edited.priority == p ? .semibold : .regular))
            }
            .foregroundStyle(edited.priority == p ? .white : priorityColor(p))
            .frame(minWidth: 60)
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(edited.priority == p ? priorityColor(p) : chipBg)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Project

    private var projectSection: some View {
        OptionRow(icon: "folder.fill", iconColor: .blue, label: "项目") {
            Menu {
                Button("无项目") { edited.projectId = nil }
                Divider()
                ForEach(store.projects) { project in
                    Button {
                        edited.projectId = project.id
                    } label: {
                        HStack {
                            Text(project.emoji + " " + project.name)
                            if edited.projectId == project.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(edited.projectId.flatMap { id in store.projects.first { $0.id == id }?.name } ?? "选择项目")
                        .foregroundStyle(edited.projectId == nil ? .secondary : .primary)
                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(chipBg)
                .clipShape(Capsule())
            }
        }
    }

    // MARK: - Tags

    private var tagSection: some View {
        OptionRow(icon: "number", iconColor: .purple, label: "标签") {
            if store.tags.isEmpty {
                Text("暂无标签")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            } else {
                FlowLayout(spacing: 8) {
                    ForEach(store.tags) { tag in
                        let isSelected = edited.tagIds.contains(tag.id)
                        Button {
                            if isSelected {
                                edited.tagIds.removeAll { $0 == tag.id }
                            } else {
                                edited.tagIds.append(tag.id)
                            }
                        } label: {
                            HStack(spacing: 4) {
                                if isSelected {
                                    Image(systemName: "checkmark")
                                        .font(.caption2)
                                }
                                Text(tag.name)
                                    .font(.subheadline.weight(isSelected ? .semibold : .regular))
                            }
                            .foregroundStyle(isSelected ? .white : .primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(isSelected ? Color.purple : chipBg)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Dates

    private var dateCard: some View {
        VStack(spacing: 16) {
            dateToggleRow(
                icon: "calendar",
                color: .green,
                label: "计划日期",
                isOn: $hasScheduled
            )
            if hasScheduled {
                DatePicker("", selection: Binding(
                    get: { edited.scheduledAt ?? Date() },
                    set: { edited.scheduledAt = $0 }
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
                    get: { edited.dueAt ?? Date() },
                    set: { edited.dueAt = $0 }
                ), displayedComponents: .date)
                .datePickerStyle(.compact)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(cardBg)
        )
    }

    private func dateToggleRow(icon: String, color: Color, label: String, isOn: Binding<Bool>) -> some View {
        HStack {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.body)
                Text(label)
                    .font(.body)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(color)
        }
    }


    // MARK: - Actions

    private var actionCard: some View {
        VStack(spacing: 12) {
            Button {
                Task {
                    try? await store.archiveTodo(id: edited.id)
                    dismiss()
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "archivebox.fill")
                        .font(.body)
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
                    try? await store.deleteTodo(id: edited.id)
                    dismiss()
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "trash.fill")
                        .font(.body)
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
                .fill(cardBg)
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
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                    Text("保存")
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
        !edited.title.isEmpty
    }

    private func priorityColor(_ p: TodoPriority) -> Color {
        switch p {
        case .low: return .gray
        case .medium: return .orange
        case .high: return .red
        }
    }

    private func save() async {
        try? await store.updateTodo(edited)
        dismiss()
    }

    // MARK: - Cross-platform colors

    #if os(iOS)
    private var cardBg: Color { Color(uiColor: .secondarySystemBackground) }
    private var chipBg: Color { Color(uiColor: .tertiarySystemFill) }
    #else
    private var cardBg: Color { Color(nsColor: .controlBackgroundColor) }
    private var chipBg: Color { Color(nsColor: .controlBackgroundColor) }
    #endif
}

// MARK: - Option Row

private struct OptionRow<Content: View>: View {
    let icon: String
    let iconColor: Color
    let label: String
    @ViewBuilder let content: Content

    private var rowBackground: Color {
        #if os(iOS)
        Color(uiColor: .systemGray6)
        #else
        Color(nsColor: .controlBackgroundColor)
        #endif
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .foregroundStyle(iconColor)
                    .font(.body)
                Text(label)
                    .font(.body.weight(.medium))
                Spacer()
            }
            content
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(rowBackground)
        )
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
