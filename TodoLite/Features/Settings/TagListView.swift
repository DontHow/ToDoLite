import SwiftUI

struct TagListView: View {
    @State private var store = TodoStore.shared
    @State private var showingCreate = false
    @State private var editingTag: TagItem? = nil

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(store.tags) { tag in
                    TagCard(
                        tag: tag,
                        taskCount: store.todos.filter { $0.tagIds.contains(tag.id) }.count
                    )
                    .contextMenu {
                        Button {
                            editingTag = tag
                        } label: {
                            Label("编辑", systemImage: "pencil")
                        }

                        Button(role: .destructive) {
                            Task { try? await store.deleteTag(id: tag.id) }
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
                }
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, 12)
        }
        .navigationTitle("标签")
        .overlay {
            if store.tags.isEmpty {
                EmptyStateView(
                    icon: "number",
                    title: "暂无标签",
                    subtitle: "点击右上角 + 创建标签"
                )
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingCreate = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingCreate) {
            TagEditorView()
        }
        .sheet(item: $editingTag) { tag in
            TagEditorView(tag: tag)
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

// MARK: - Tag Card

private struct TagCard: View {
    let tag: TagItem
    let taskCount: Int
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(hex: tag.colorHex).opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: "number")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color(hex: tag.colorHex))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(tag.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text("\(taskCount) 任务")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.labelSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.chipBackground)
                    .clipShape(Capsule())
            }

            Spacer()

            HStack(spacing: 8) {
                Circle()
                    .fill(Color(hex: tag.colorHex))
                    .frame(width: 10, height: 10)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.labelSecondary)
            }

            #if os(macOS)
            Button {
                Task { try? await TodoStore.shared.deleteTag(id: tag.id) }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .opacity(isHovering ? 1 : 0)
            .animation(.easeInOut(duration: 0.15), value: isHovering)
            #endif
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.cardBackground)
                .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.separatorColor.opacity(0.5), lineWidth: 0.5)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

// MARK: - Tag Editor

private struct TagEditorView: View {
    @State private var store = TodoStore.shared
    @State private var name = ""
    @State private var selectedColor = "#FF9500"
    @Environment(\.dismiss) private var dismiss

    var tag: TagItem? = nil
    var isEditing: Bool { tag != nil }

    private let presetColors: [String] = [
        "#FF3B30", "#FF9500", "#FFCC00", "#4CD964",
        "#5AC8FA", "#007AFF", "#5856D6", "#FF2D55",
        "#8E8E93", "#C7C7CC", "#34C759", "#AF52DE"
    ]

    init(tag: TagItem? = nil) {
        self.tag = tag
        if let tag = tag {
            _name = State(initialValue: tag.name)
            _selectedColor = State(initialValue: tag.colorHex)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    previewSection
                    nameSection
                    colorSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .navigationTitle(isEditing ? "编辑标签" : "新建标签")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(isEditing ? "保存" : "创建") {
                        Task {
                            if let tag = tag {
                                var updated = tag
                                updated.name = name
                                updated.colorHex = selectedColor
                                try? await store.updateTag(updated)
                            } else {
                                try? await store.createTag(name: name, colorHex: selectedColor)
                            }
                            dismiss()
                        }
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }

    private var previewSection: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(hex: selectedColor).opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: "number")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color(hex: selectedColor))
            }

            Text(name.isEmpty ? "预览" : name)
                .font(.body.weight(.semibold))
                .foregroundStyle(name.isEmpty ? Color.labelSecondary : .primary)
                .lineLimit(1)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.separatorColor.opacity(0.5), lineWidth: 0.5)
        )
    }

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "textformat")
                    .foregroundStyle(.primary)
                    .font(.body)
                    .symbolRenderingMode(.hierarchical)
                Text("名称")
                    .font(.callout.weight(.medium))
            }

            TextField("输入标签名称", text: $name)
                .font(.body.weight(.semibold))
        }
        .padding(18)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var colorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "paintpalette")
                    .foregroundStyle(.primary)
                    .font(.body)
                    .symbolRenderingMode(.hierarchical)
                Text("颜色")
                    .font(.callout.weight(.medium))
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 12) {
                ForEach(presetColors, id: \.self) { hex in
                    Button {
                        withAnimation(.spring(duration: 0.25)) {
                            selectedColor = hex
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 40, height: 40)

                            if selectedColor == hex {
                                Image(systemName: "checkmark")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .scaleEffect(selectedColor == hex ? 1.1 : 1.0)
                    .animation(.spring(duration: 0.25), value: selectedColor)
                }
            }
        }
        .padding(18)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}
