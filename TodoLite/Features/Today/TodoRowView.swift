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
                .foregroundStyle(todo.status == .done ? TodoStatus.done.theme.primaryText : Color.labelSecondary)
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
                focusChip
                projectChip
                tagChips
            }
            .layoutPriority(1)

            Spacer(minLength: 8)

            dateChip
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
            .font(.caption.weight(.medium))
            .foregroundStyle(SectionTheme.today.secondaryText)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(SectionTheme.today.softBackground)
            .clipShape(Capsule())
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
        if let completedAt = todo.completedAt, todo.status == .done {
            HStack(spacing: 3) {
                Image(systemName: "checkmark.circle")
                    .imageScale(.small)
                Text(completedAt.formatted(.dateTime.month().day()))
            }
            .font(.caption)
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
            .font(.caption)
            .foregroundStyle(isOverdue ? .red : (isUpcoming ? SectionTheme.upcoming.secondaryText : SectionTheme.today.secondaryText))
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(isOverdue ? Color.overdue : (isUpcoming ? SectionTheme.upcoming.softBackground : SectionTheme.today.softBackground))
            .clipShape(Capsule())
            .layoutPriority(0)
        }
    }

    private var hasMetadata: Bool {
        isInFocus || todo.projectId != nil || !todo.tagIds.isEmpty || todo.dueAt != nil
    }

    private var isInFocus: Bool {
        store.focusSet.taskIds.contains(todo.id)
    }

    private func relativeDateString(_ date: Date) -> String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let target = calendar.startOfDay(for: date)

        guard let daysDiff = calendar.dateComponents([.day], from: today, to: target).day else {
            return date.formatted(.dateTime.month().day())
        }

        let weekdays = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
        let weekday = calendar.component(.weekday, from: target) - 1

        switch daysDiff {
        case 0: return "今天"
        case 1: return "明天"
        case 2: return "后天"
        case 3...6:
            let todayWeek = calendar.component(.weekOfYear, from: today)
            let targetWeek = calendar.component(.weekOfYear, from: target)
            return todayWeek == targetWeek ? weekdays[weekday] : "下周\(weekdays[weekday])"
        case 7...13:
            return "下周\(weekdays[weekday])"
        case -1: return "昨天"
        case -2: return "前天"
        case -6...(-3):
            let todayWeek = calendar.component(.weekOfYear, from: today)
            let targetWeek = calendar.component(.weekOfYear, from: target)
            return todayWeek == targetWeek ? "本周\(weekdays[weekday])" : "上周\(weekdays[weekday])"
        case -13...(-7):
            return "上周\(weekdays[weekday])"
        default:
            return date.formatted(.dateTime.month().day())
        }
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
