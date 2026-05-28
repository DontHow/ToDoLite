import SwiftUI

struct ProjectListView: View {
    @State private var store = TodoStore.shared
    @State private var showingCreate = false
    @State private var editingProject: Project? = nil

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(store.projects) { project in
                    ProjectCard(
                        project: project,
                        taskCount: store.todos.filter { $0.projectId == project.id }.count
                    )
                    .contextMenu {
                        Button {
                            editingProject = project
                        } label: {
                            Label("编辑", systemImage: "pencil")
                        }

                        Button(role: .destructive) {
                            Task { try? await store.deleteProject(id: project.id) }
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
                }
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, 12)
        }
        .navigationTitle("项目")
        .overlay {
            if store.projects.isEmpty {
                EmptyStateView(
                    icon: "folder",
                    title: "暂无项目",
                    subtitle: "点击右上角 + 创建项目"
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
            ProjectEditorView()
        }
        .sheet(item: $editingProject) { project in
            ProjectEditorView(project: project)
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

// MARK: - Project Card

private struct ProjectCard: View {
    let project: Project
    let taskCount: Int
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 14) {
            Text(project.emoji)
                .font(.system(size: 28))
                .frame(width: 44, height: 44)
                .background(Color.cardBackgroundTertiary)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(project.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text("\(taskCount) 任务")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.labelSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.chipBackground)
                        .clipShape(Capsule())
                }
            }

            Spacer()

            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(hex: project.colorHex))
                    .frame(width: 4, height: 28)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.labelSecondary)
            }

            #if os(macOS)
            Button {
                Task { try? await TodoStore.shared.deleteProject(id: project.id) }
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

// MARK: - Project Editor

private struct ProjectEditorView: View {
    @State private var store = TodoStore.shared
    @State private var name = ""
    @State private var selectedEmoji = "📁"
    @State private var selectedColor = "#007AFF"
    @Environment(\.dismiss) private var dismiss

    var project: Project? = nil
    var isEditing: Bool { project != nil }

    private let presetEmojis = [
        "📁", "💼", "🏠", "🎓", "✈️", "🛒", "💰", "🏋️",
        "🎨", "🎵", "📚", "💻", "🌱", "🔧", "📝", "🎯"
    ]

    private let presetColors: [String] = [
        "#FF3B30", "#FF9500", "#FFCC00", "#4CD964",
        "#5AC8FA", "#007AFF", "#5856D6", "#FF2D55",
        "#8E8E93", "#C7C7CC", "#34C759", "#AF52DE"
    ]

    init(project: Project? = nil) {
        self.project = project
        if let project = project {
            _name = State(initialValue: project.name)
            _selectedEmoji = State(initialValue: project.emoji)
            _selectedColor = State(initialValue: project.colorHex)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    previewSection
                    nameSection
                    emojiSection
                    colorSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .navigationTitle(isEditing ? "编辑项目" : "新建项目")
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
                            if let project = project {
                                var updated = project
                                updated.name = name
                                updated.emoji = selectedEmoji
                                updated.colorHex = selectedColor
                                try? await store.updateProject(updated)
                            } else {
                                try? await store.createProject(name: name, emoji: selectedEmoji, colorHex: selectedColor)
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
            Text(selectedEmoji)
                .font(.system(size: 32))
                .frame(width: 52, height: 52)
                .background(Color.cardBackgroundTertiary)
                .clipShape(RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 4) {
                Text(name.isEmpty ? "预览" : name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(name.isEmpty ? Color.labelSecondary : .primary)
                    .lineLimit(1)

                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(hex: selectedColor))
                    .frame(width: 24, height: 4)
            }

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

            TextField("输入项目名称", text: $name)
                .font(.body.weight(.semibold))
        }
        .padding(18)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var emojiSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "face.smiling")
                    .foregroundStyle(.primary)
                    .font(.body)
                    .symbolRenderingMode(.hierarchical)
                Text("图标")
                    .font(.callout.weight(.medium))
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 48))], spacing: 12) {
                ForEach(presetEmojis, id: \.self) { emoji in
                    Button {
                        withAnimation(.spring(duration: 0.25)) {
                            selectedEmoji = emoji
                        }
                    } label: {
                        Text(emoji)
                            .font(.system(size: 24))
                            .frame(width: 48, height: 48)
                            .background(
                                selectedEmoji == emoji
                                ? Color(hex: selectedColor).opacity(0.15)
                                : Color.cardBackgroundTertiary
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        selectedEmoji == emoji
                                        ? Color(hex: selectedColor)
                                        : Color.clear,
                                        lineWidth: 2
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    .scaleEffect(selectedEmoji == emoji ? 1.05 : 1.0)
                    .animation(.spring(duration: 0.25), value: selectedEmoji)
                }
            }
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
