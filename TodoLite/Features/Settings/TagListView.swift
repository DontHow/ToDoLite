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
                        taskCount: store.todos.filter { $0.tagIds.contains(tag.id) }.count,
                        onEdit: { editingTag = tag }
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
                    icon: "tag.fill",
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
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            TagIcon(colorHex: tag.colorHex, size: 44, cornerRadius: 12)

            VStack(alignment: .leading, spacing: 4) {
                Text(tag.name)
                    .appFont(.body, weight: .semibold)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text("\(taskCount) 任务")
                    .appFont(.caption, weight: .medium)
                    .foregroundStyle(Color.labelSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.chipBackground)
                    .clipShape(Capsule())
            }

            Spacer()

            Button {
                Task { try? await TodoStore.shared.deleteTag(id: tag.id) }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "trash.fill")
                        .appFont(.body)
                    Text("删除")
                        .appFont(.caption, weight: .medium)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.red)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
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
        .onTapGesture(perform: onEdit)
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
            TagIcon(colorHex: selectedColor, size: 44, cornerRadius: 12)

            Text(name.isEmpty ? "预览" : name)
                .appFont(.body, weight: .semibold)
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
                    .appFont(.body)
                    .symbolRenderingMode(.hierarchical)
                Text("名称")
                    .appFont(.callout, weight: .medium)
            }

            TextField("输入标签名称", text: $name)
                .appFont(.body, weight: .semibold)
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
                    .appFont(.body)
                    .symbolRenderingMode(.hierarchical)
                Text("颜色")
                    .appFont(.callout, weight: .medium)
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
                                    .appFont(.caption, weight: .bold)
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

private struct TagIcon: View {
    let colorHex: String
    let size: CGFloat
    let cornerRadius: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color(hex: colorHex).opacity(0.16))

            Image(systemName: "tag.fill")
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(Color(hex: colorHex))
                .symbolRenderingMode(.hierarchical)
        }
        .frame(width: size, height: size)
    }
}
