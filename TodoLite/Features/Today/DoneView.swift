import SwiftUI

struct DoneView: View {
    @State private var store = TodoStore.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(store.todos.filter { $0.status == .done }) { todo in
                        NavigationLink(destination: TodoDetailView(todo: todo)) {
                            TodoRowView(todo: todo)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color.cardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(CardButtonStyle())
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
