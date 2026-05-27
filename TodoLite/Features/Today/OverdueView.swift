import SwiftUI

struct OverdueView: View {
    @State private var store = TodoStore.shared

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.overdueTodos) { todo in
                    TodoRowView(todo: todo)
                }
            }
            .navigationTitle("逾期")
            .overlay {
                if store.overdueTodos.isEmpty {
                    EmptyStateView(
                        icon: "checkmark.seal.fill",
                        title: "没有逾期任务",
                        subtitle: "保持节奏，一切都在掌控中"
                    )
                }
            }
        }
    }
}
