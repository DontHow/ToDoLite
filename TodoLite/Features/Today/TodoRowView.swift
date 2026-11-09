import SwiftUI

struct TodoRowView: View {
    let todo: TodoItem
    let showsProject: Bool
    var showsDate = true
    @State private var store = TodoStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            titleText

            if hasMetadata {
                metadataRow
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }

    // MARK: - Title

    private var titleText: some View {
        Text(todo.title)
            .appFont(.body, weight: .semibold)
            .foregroundStyle(todo.status == .done ? Color.labelSecondary : .primary)
            .lineLimit(2)
    }

    // MARK: - Metadata

    private var metadataRow: some View {
        HStack(spacing: 0) {
            HStack(spacing: 6) {
                focusChip
                projectChip
                tagChips
            }
            .lineLimit(1)

            Spacer(minLength: 8)

            if showsDate {
                dateChip.fixedSize(horizontal: true, vertical: false)
            }
        }
    }

    @ViewBuilder
    private var focusChip: some View {
        if isInFocus {
            HStack(spacing: 3) {
                Image(systemName: "sun.max.fill")
                    .imageScale(.small)
                Text("今日")
            }
            .appFont(.caption, weight: .medium)
            .foregroundStyle(SectionTheme.today.secondaryText)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(SectionTheme.today.softBackground)
            .clipShape(Capsule())
        }
    }

    @ViewBuilder
    private var projectChip: some View {
        if showsProject, let project = store.projects.first(where: { $0.id == todo.projectId }) {
            HStack(spacing: 3) {
                Image(systemName: "folder")
                    .imageScale(.small)
                Text(project.name)
            }
            .appFont(.caption)
            .foregroundStyle(Color.labelSecondary)
        }
    }

    @ViewBuilder
    private var tagChips: some View {
        let tagList = todo.tagIds.compactMap { id in store.tags.first(where: { $0.id == id }) }
        ForEach(tagList) { tag in
            Text(tag.name)
                .appFont(.caption, weight: .medium)
                .foregroundStyle(Color(hex: tag.colorHex))
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(Color(hex: tag.colorHex).opacity(0.12))
                .clipShape(Capsule())
        }
    }

    @ViewBuilder
    private var dateChip: some View {
        if let completedAt = todo.completedAt, todo.status == .done {
            HStack(spacing: 3) {
                Image(systemName: "checkmark.circle")
                    .imageScale(.small)
                Text(shortDate(completedAt))
            }
            .appFont(.caption)
            .foregroundStyle(SectionTheme.done.secondaryText)
            .layoutPriority(0)
        } else if let due = todo.dueAt {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let dueDay = calendar.startOfDay(for: due)
            let isOverdue = dueDay < today
            let isUpcoming = dueDay > today

            HStack(spacing: 3) {
                Image(systemName: "calendar")
                    .imageScale(.small)
                Text(relativeDateString(due))
            }
            .appFont(.caption)
            .foregroundStyle(isOverdue ? .red : (isUpcoming ? SectionTheme.upcoming.secondaryText : SectionTheme.today.secondaryText))
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(isOverdue ? Color.overdue : (isUpcoming ? SectionTheme.upcoming.softBackground : SectionTheme.today.softBackground))
            .clipShape(Capsule())
            .layoutPriority(0)
        }
    }

    private var hasMetadata: Bool {
        isInFocus || (showsProject && todo.projectId != nil) || !todo.tagIds.isEmpty
            || (showsDate && (todo.dueAt != nil || (todo.status == .done && todo.completedAt != nil)))
    }

    private var isInFocus: Bool {
        store.focusSet.taskIds.contains(todo.id)
    }

    private func relativeDateString(_ date: Date) -> String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let target = calendar.startOfDay(for: date)

        guard let daysDiff = calendar.dateComponents([.day], from: today, to: target).day else {
            return shortDate(date)
        }

        switch daysDiff {
        case 0: return "今天"
        case 1: return "明天"
        case 2: return "后天"
        default:
            return shortDate(date)
        }
    }

    private func shortDate(_ date: Date) -> String {
        date.formatted(.dateTime.month().day().locale(Locale(identifier: "zh_CN")))
    }
}
