import SwiftUI

struct TodoDetailView: View {
    let todo: TodoItem
    @State private var store = TodoStore.shared
    @State private var edited: TodoItem
    @State private var hasDue: Bool
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    init(todo: TodoItem) {
        self.todo = todo
        _edited = State(initialValue: todo)
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
            .alert("错误", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
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
                .font(.body.weight(.semibold))

            Divider()

            TextField("添加描述...", text: $edited.description, axis: .vertical)
                .lineLimit(2...6)
                .font(.body)
                .foregroundStyle(Color.labelSecondary)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.cardBackground)
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
                .font(.callout.weight(edited.status == s ? .semibold : .regular))
                .foregroundStyle(edited.status == s ? .white : .primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(edited.status == s ? Color.indigo : Color.chipBackground)
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
                    .font(.caption)
                Text(p.displayName)
                    .font(.callout.weight(edited.priority == p ? .semibold : .regular))
            }
            .foregroundStyle(edited.priority == p ? .white : priorityColor(p))
            .frame(minWidth: 60)
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(edited.priority == p ? priorityColor(p) : Color.chipBackground)
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
                        .foregroundStyle(edited.projectId == nil ? Color.labelSecondary : .primary)
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.labelSecondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.chipBackground)
                .clipShape(Capsule())
            }
        }
    }

    // MARK: - Tags

    private var tagSection: some View {
        OptionRow(icon: "number", iconColor: .purple, label: "标签") {
            if store.tags.isEmpty {
                Text("暂无标签")
                    .font(.callout)
                    .foregroundStyle(Color.labelSecondary)
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
                                    .font(.callout.weight(isSelected ? .semibold : .regular))
                            }
                            .foregroundStyle(isSelected ? .white : .primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(isSelected ? Color.purple : Color.chipBackground)
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
                .fill(Color.cardBackground)
        )
    }

    private func dateToggleRow(icon: String, color: Color, label: String, isOn: Binding<Bool>) -> some View {
        HStack {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.body)
                    .symbolRenderingMode(.hierarchical)
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
        do {
            try await store.updateTodo(edited)
            dismiss()
        } catch {
            errorMessage = "保存失败: \(error.localizedDescription)"
        }
    }
}
