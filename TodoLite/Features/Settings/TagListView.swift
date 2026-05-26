import SwiftUI

struct TagListView: View {
    @State private var store = TodoStore.shared
    @State private var showingCreate = false
    @State private var newName = ""

    var body: some View {
        List {
            ForEach(store.tags) { tag in
                HStack {
                    Text(tag.name)
                    Spacer()
                    Circle()
                        .fill(Color(hex: tag.colorHex))
                        .frame(width: 12, height: 12)
                }
            }
            .onDelete { indexSet in
                for idx in indexSet {
                    let tag = store.tags[idx]
                    Task {
                        try? await store.deleteTag(id: tag.id)
                    }
                }
            }
        }
        .navigationTitle("标签")
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
}
