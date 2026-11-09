import SwiftUI

struct ArchiveView: View {
    @State private var store = TodoStore.shared

    var body: some View {
        let archived = store.todos.filter { $0.status == .archived }
        Group {
            if archived.isEmpty {
                EmptyStateView(
                    icon: "archivebox",
                    title: "归档为空",
                    subtitle: "已完成的任务可以归档到这里"
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    TaskListView(title: "已归档", todos: archived, accentTheme: .archived)
                        .padding(.horizontal, horizontalPadding)
                        .padding(.vertical, 12)
                }
            }
        }
        .navigationTitle("已归档")
    }

    private var horizontalPadding: CGFloat {
        #if os(iOS)
        16
        #else
        12
        #endif
    }
}
