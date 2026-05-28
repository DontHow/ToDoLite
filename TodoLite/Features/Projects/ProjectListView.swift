import SwiftUI

struct ProjectListView: View {
    @State private var store = TodoStore.shared
    @State private var showingCreate = false
    @State private var newName = ""

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(store.projects) { project in
                    HStack {
                        Text(project.emoji)
                        Text(project.name)
                            .font(.body.weight(.medium))
                        Spacer()
                        Circle()
                            .fill(Color(hex: project.colorHex))
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
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .navigationTitle("项目")
        .overlay {
            if store.projects.isEmpty {
                EmptyStateView(
                    icon: "folder",
                    title: "暂无项目",
                    subtitle: "在设置中创建项目"
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
        .alert("新建项目", isPresented: $showingCreate) {
            TextField("名称", text: $newName)
            Button("取消", role: .cancel) { newName = "" }
            Button("创建") {
                Task {
                    try? await store.createProject(name: newName)
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
