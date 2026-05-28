import SwiftUI

struct TodoListCard: View {
    let todo: TodoItem
    var isDraggable: Bool = false

    var body: some View {
        NavigationLink(destination: TodoDetailView(todo: todo)) {
            TodoRowView(todo: todo)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.cardBackground)
                        .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 3)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.separatorColor.opacity(0.5), lineWidth: 0.5)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(CardButtonStyle())
        .draggable(isDraggable ? todo.id : "")
    }
}
