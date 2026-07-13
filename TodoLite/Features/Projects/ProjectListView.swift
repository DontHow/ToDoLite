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
                        taskCount: store.todos.filter { $0.projectId == project.id }.count,
                        onEdit: { editingProject = project }
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
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            ProjectIcon(colorHex: project.colorHex, size: 44, cornerRadius: 12)

            VStack(alignment: .leading, spacing: 4) {
                Text(project.name)
                    .appFont(.body, weight: .semibold)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text("\(taskCount) 任务")
                        .appFont(.caption, weight: .medium)
                        .foregroundStyle(Color.labelSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.chipBackground)
                        .clipShape(Capsule())
                }
            }

            Spacer()

            Button {
                Task { try? await TodoStore.shared.deleteProject(id: project.id) }
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

// MARK: - Project Editor

private struct ProjectEditorView: View {
    @State private var store = TodoStore.shared
    @State private var name = ""
    @State private var selectedColor = "#007AFF"
    @Environment(\.dismiss) private var dismiss

    var project: Project? = nil
    var isEditing: Bool { project != nil }

    private let presetColors: [String] = [
        "#FF3B30", "#FF9500", "#FFCC00", "#4CD964",
        "#5AC8FA", "#007AFF", "#5856D6", "#FF2D55",
        "#8E8E93", "#C7C7CC", "#34C759", "#AF52DE"
    ]

    init(project: Project? = nil) {
        self.project = project
        if let project = project {
            _name = State(initialValue: project.name)
            _selectedColor = State(initialValue: project.colorHex)
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
                                updated.colorHex = selectedColor
                                try? await store.updateProject(updated)
                            } else {
                                try? await store.createProject(name: name, colorHex: selectedColor)
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
            ProjectIcon(colorHex: selectedColor, size: 52, cornerRadius: 14)

            VStack(alignment: .leading, spacing: 4) {
                Text(name.isEmpty ? "预览" : name)
                    .appFont(.body, weight: .semibold)
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
                    .appFont(.body)
                    .symbolRenderingMode(.hierarchical)
                Text("名称")
                    .appFont(.callout, weight: .medium)
            }

            TextField("输入项目名称", text: $name)
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

private struct ProjectIcon: View {
    let colorHex: String
    let size: CGFloat
    let cornerRadius: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color(hex: colorHex).opacity(0.16))

            Image(systemName: "folder.fill")
                .font(.system(size: size * 0.43, weight: .semibold))
                .foregroundStyle(Color(hex: colorHex))
                .symbolRenderingMode(.hierarchical)
        }
        .frame(width: size, height: size)
    }
}
