import SwiftUI

struct DoneView: View {
    @State private var store = TodoStore.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(store.todos.filter { $0.status == .done }) { todo in
                        TodoListCard(todo: todo)
                    }
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, 12)
            }
            .navigationTitle("已完成")
            .overlay {
                if !store.todos.contains(where: { $0.status == .done }) {
                    EmptyStateView(
                        icon: "checkmark.circle",
                        title: "还没有完成的任务",
                        subtitle: "去收件箱或看板开始行动吧"
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
