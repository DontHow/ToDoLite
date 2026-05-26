import SwiftUI

struct ProjectListView: View {
    @State private var store = TodoStore.shared
    @State private var showingCreate = false
    @State private var newName = ""

    var body: some View {
        List {
            ForEach(store.projects) { project in
                HStack {
                    Text(project.emoji)
                    Text(project.name)
                    Spacer()
                    Circle()
                        .fill(Color(hex: project.colorHex))
                        .frame(width: 12, height: 12)
                }
            }
            .onDelete { indexSet in
                for idx in indexSet {
                    let project = store.projects[idx]
                    Task {
                        try? await store.deleteProject(id: project.id)
                    }
                }
            }
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
}
