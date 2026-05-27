import SwiftUI

struct TodoRowView: View {
    let todo: TodoItem
    @State private var store = TodoStore.shared

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            completeButton

            VStack(alignment: .leading, spacing: 4) {
                titleText

                if hasMetadata {
                    metadataRow
                }
            }

            Spacer()
        }
        .padding(.vertical, 8)
    }

    // MARK: - Complete Button

    private var completeButton: some View {
        Button(action: {
            Task {
                try? await store.toggleComplete(id: todo.id)
            }
        }) {
            Image(systemName: todo.status == .done ? "checkmark.circle.fill" : "circle")
                .font(.body)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(todo.status == .done ? .green : Color.labelSecondary)
        }
        .buttonStyle(ScaleButtonStyle())
        .padding(.top, 1)
    }

    // MARK: - Title

    private var titleText: some View {
        Text(todo.title)
            .font(.body.weight(.semibold))
            .strikethrough(todo.status == .done)
            .foregroundStyle(todo.status == .done ? Color.labelSecondary : .primary)
            .lineLimit(2)
    }

    // MARK: - Metadata

    private var metadataRow: some View {
        HStack(spacing: 0) {
            HStack(spacing: 6) {
                projectChip
                tagChips
            }
            .layoutPriority(1)

            Spacer(minLength: 8)

            dateChip
        }
    }

    @ViewBuilder
    private var projectChip: some View {
        if let project = store.projects.first(where: { $0.id == todo.projectId }) {
            HStack(spacing: 3) {
                Image(systemName: "folder")
                    .imageScale(.small)
                Text(project.name)
            }
            .font(.caption)
            .foregroundStyle(Color.labelSecondary)
        }
    }

    @ViewBuilder
    private var tagChips: some View {
        let tagList = todo.tagIds.compactMap { id in store.tags.first(where: { $0.id == id }) }
        ForEach(tagList) { tag in
            Text(tag.name)
                .font(.caption.weight(.medium))
                .foregroundStyle(Color(hex: tag.colorHex))
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(Color(hex: tag.colorHex).opacity(0.12))
                .clipShape(Capsule())
        }
    }

    @ViewBuilder
    private var dateChip: some View {
        if let due = todo.dueAt {
            HStack(spacing: 3) {
                Image(systemName: "calendar")
                    .imageScale(.small)
                Text(due, style: .date)
            }
            .font(.caption)
            .foregroundStyle(due < Date() ? .red : Color.labelSecondary)
            .layoutPriority(0)
        }
    }

    private var hasMetadata: Bool {
        todo.projectId != nil || !todo.tagIds.isEmpty || todo.dueAt != nil
    }
}

// MARK: - Scale Button Style

private struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.85 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}
