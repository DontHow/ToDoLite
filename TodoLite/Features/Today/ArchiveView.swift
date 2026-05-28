import SwiftUI

struct ArchiveView: View {
    @State private var store = TodoStore.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                TaskListView(title: "已归档", todos: store.todos.filter { $0.status == .archived })
                    .padding(.horizontal, horizontalPadding)
                    .padding(.vertical, 12)
            }
            .navigationTitle("已归档")
            .overlay {
                if !store.todos.contains(where: { $0.status == .archived }) {
                    EmptyStateView(
                        icon: "archivebox",
                        title: "归档为空",
                        subtitle: "已完成的任务可以归档到这里"
                    )
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
