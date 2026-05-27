import SwiftUI

struct TodoRowView: View {
    let todo: TodoItem
    @State private var store = TodoStore.shared

    var body: some View {
        HStack(spacing: 12) {
            Button(action: {
                Task {
                    try? await store.toggleComplete(id: todo.id)
                }
            }) {
                Image(systemName: todo.status == .done ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(todo.status == .done ? .green : .secondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(todo.title)
                    .strikethrough(todo.status == .done)
                    .foregroundStyle(todo.status == .done ? .secondary : .primary)

                HStack(spacing: 6) {
                    if let project = store.projects.first(where: { $0.id == todo.projectId }) {
                        Text(project.emoji + " " + project.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    ForEach(todo.tagIds.compactMap { id in store.tags.first(where: { $0.id == id }) }) { tag in
                        Text(tag.name)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(hex: tag.colorHex).opacity(0.2))
                            .clipShape(Capsule())
                    }

                    if let due = todo.dueAt {
                        Text(due, style: .date)
                            .font(.caption)
                            .foregroundStyle(due < Date() ? .red : .secondary)
                    }
                }
            }

            Spacer()

        }
        .padding(.vertical, 4)
    }
}
