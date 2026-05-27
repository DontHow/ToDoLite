import SwiftUI

struct TodoRowView: View {
    let todo: TodoItem
    @State private var store = TodoStore.shared

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            completeButton

            VStack(alignment: .leading, spacing: 6) {
                titleText

                if hasMetadata {
                    metadataRow
                }
            }

            Spacer()
        }
        .padding(.vertical, 10)
    }

    // MARK: - Components

    private var completeButton: some View {
        Button(action: {
            Task {
                try? await store.toggleComplete(id: todo.id)
            }
        }) {
            Image(systemName: todo.status == .done ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(todo.status == .done ? .green : Color.labelSecondary)
                .font(.body)
                .symbolRenderingMode(.hierarchical)
        }
        .buttonStyle(.plain)
        .padding(.top, 2)
    }

    private var titleText: some View {
        Text(todo.title)
            .font(.callout.weight(.semibold))
            .strikethrough(todo.status == .done)
            .foregroundStyle(todo.status == .done ? Color.labelSecondary : .primary)
            .lineLimit(2)
    }

    private var metadataRow: some View {
        HStack(spacing: 0) {
            if let project = store.projects.first(where: { $0.id == todo.projectId }) {
                HStack(spacing: 4) {
                    Image(systemName: "folder")
                        .font(.caption2)
                    Text(project.name)
                }
                .foregroundStyle(Color.labelSecondary)
            }

            let tagList = todo.tagIds.compactMap { id in store.tags.first(where: { $0.id == id }) }

            if store.projects.first(where: { $0.id == todo.projectId }) != nil && !tagList.isEmpty {
                separatorDot
            }

            ForEach(Array(tagList.enumerated()), id: \.element.id) { index, tag in
                if index > 0 {
                    separatorDot
                }
                Text(tag.name)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Color(hex: tag.colorHex))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(hex: tag.colorHex).opacity(0.12))
                    .clipShape(Capsule())
            }

            if let due = todo.dueAt {
                if (store.projects.first(where: { $0.id == todo.projectId }) != nil || !tagList.isEmpty) {
                    separatorDot
                }
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.caption2)
                    Text(due, style: .date)
                }
                .foregroundStyle(due < Date() ? .red : Color.labelSecondary)
            }
        }
        .font(.caption)
    }

    private var separatorDot: some View {
        Text(" · ")
            .font(.caption)
            .foregroundStyle(Color.labelSecondary)
    }

    private var hasMetadata: Bool {
        todo.projectId != nil || !todo.tagIds.isEmpty || todo.dueAt != nil
    }
}
