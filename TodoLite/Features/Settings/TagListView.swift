import SwiftUI

struct TagListView: View {
    @State private var store = TodoStore.shared
    @State private var showingCreate = false

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                Text("标签")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(store.tags) { tag in
                    TagRow(tag: tag)
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
            CreateTagView()
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

// MARK: - Tag Row

private struct TagRow: View {
    let tag: TagItem
    @State private var store = TodoStore.shared
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(hex: tag.colorHex))
                .frame(width: 10, height: 10)

            Text(tag.name)
                .font(.body.weight(.medium))

            Spacer()

            #if os(macOS)
            Button {
                Task { try? await store.deleteTag(id: tag.id) }
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
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
        }
        .contextMenu {
            Button(role: .destructive) {
                Task { try? await store.deleteTag(id: tag.id) }
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
    }
}

// MARK: - Create Tag

private struct CreateTagView: View {
    @State private var store = TodoStore.shared
    @State private var name = ""
    @State private var selectedColor = "#FF9500"
    @Environment(\.dismiss) private var dismiss

    private let presetColors: [String] = [
        "#FF3B30", "#FF9500", "#FFCC00", "#4CD964",
        "#5AC8FA", "#007AFF", "#5856D6", "#FF2D55",
        "#8E8E93", "#C7C7CC", "#34C759", "#AF52DE"
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    nameSection
                    colorSection
                    previewSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .navigationTitle("新建标签")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("创建") {
                        Task {
                            try? await store.createTag(name: name, colorHex: selectedColor)
                            dismiss()
                        }
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
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

    private var previewSection: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(hex: selectedColor))
                .frame(width: 10, height: 10)

            Text(name.isEmpty ? "预览" : name)
                .font(.callout.weight(.medium))
                .foregroundStyle(name.isEmpty ? Color.labelSecondary : .primary)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.separatorColor.opacity(0.5), lineWidth: 0.5)
        )
    }
}
