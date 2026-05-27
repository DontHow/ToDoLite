import SwiftUI

struct ArchiveView: View {
    @State private var store = TodoStore.shared

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.todos.filter { $0.status == .archived }) { todo in
                    NavigationLink(destination: TodoDetailView(todo: todo)) {
                        TodoRowView(todo: todo)
                    }
                }
                .onDelete { indexSet in
                    let archived = store.todos.filter { $0.status == .archived }
                    for idx in indexSet {
                        let todo = archived[idx]
                        Task {
                            try? await store.deleteTodo(id: todo.id)
                        }
                    }
                }
            }
            .navigationTitle("已归档")
            .animation(.default, value: store.todos.filter { $0.status == .archived }.map(\.id))
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
}
