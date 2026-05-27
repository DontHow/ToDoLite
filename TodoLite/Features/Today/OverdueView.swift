import SwiftUI

struct OverdueView: View {
    @State private var store = TodoStore.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    Text("逾期")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    ForEach(store.overdueTodos) { todo in
                        TodoListCard(todo: todo)
                    }
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, 12)
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

    private var horizontalPadding: CGFloat {
        #if os(iOS)
        16
        #else
        12
        #endif
    }
}
