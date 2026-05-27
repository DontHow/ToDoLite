import SwiftUI

struct DoneView: View {
    @State private var store = TodoStore.shared

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.todos.filter { $0.status == .done }) { todo in
                    NavigationLink(destination: TodoDetailView(todo: todo)) {
                        TodoRowView(todo: todo)
                    }
                }
            }
            .navigationTitle("已完成")
            .animation(.default, value: store.todos.filter { $0.status == .done }.map(\.id))
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
}
