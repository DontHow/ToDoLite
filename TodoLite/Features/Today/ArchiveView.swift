import SwiftUI

struct ArchiveView: View {
    @State private var store = TodoStore.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    Text("已归档")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    ForEach(store.todos.filter { $0.status == .archived }) { todo in
                        TodoListCard(todo: todo)
                    }
                }
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
