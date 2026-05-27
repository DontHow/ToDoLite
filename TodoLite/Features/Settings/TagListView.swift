import SwiftUI

struct TagListView: View {
    @State private var store = TodoStore.shared
    @State private var showingCreate = false
    @State private var newName = ""

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(store.tags) { tag in
                    HStack {
                        Text(tag.name)
                            .font(.callout.weight(.medium))
                        Spacer()
                        Circle()
                            .fill(Color(hex: tag.colorHex))
                            .frame(width: 12, height: 12)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
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
                    subtitle: "点击 + 创建标签"
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
        .alert("新建标签", isPresented: $showingCreate) {
            TextField("名称", text: $newName)
            Button("取消", role: .cancel) { newName = "" }
            Button("创建") {
                Task {
                    try? await store.createTag(name: newName)
                    newName = ""
                }
            }
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
