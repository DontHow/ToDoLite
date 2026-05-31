import SwiftUI

func defaultDueDate() -> Date {
    let calendar = Calendar.current
    var date = Date()
    var weekdaysAdded = 0
    while weekdaysAdded < 3 {
        date = calendar.date(byAdding: .day, value: 1, to: date)!
        let weekday = calendar.component(.weekday, from: date)
        if weekday != 1 && weekday != 7 {
            weekdaysAdded += 1
        }
    }
    return date
}

extension CreateTodoView {
    func sectionHeader(icon: String, color: Color, title: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.body)
                .symbolRenderingMode(.hierarchical)
            Text(title)
                .font(.callout.weight(.medium))
            Spacer()
        }
    }

    func quickDateButton(_ title: String, date: Date) -> some View {
        let isSelected = edited.dueAt.map { Calendar.current.isDate($0, inSameDayAs: date) } ?? false
        return Button {
            withAnimation(.spring(duration: 0.2)) {
                edited.dueAt = date
            }
        } label: {
            Text(title)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .white : .primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(isSelected ? Color.orange : Color.chipBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    var customDateButton: some View {
        Text("自定义")
            .font(.subheadline)
            .foregroundStyle(Color.labelSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color.chipBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    func nextMonday() -> Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today)
        let daysUntilNextMonday = ((9 - weekday) % 7) == 0 ? 7 : ((9 - weekday) % 7)
        return calendar.date(byAdding: .day, value: daysUntilNextMonday, to: today) ?? today
    }

    func searchField(text: Binding<String>, placeholder: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.caption)
                .foregroundStyle(Color.labelSecondary)
            TextField(placeholder, text: text)
                .font(.subheadline)
                .textFieldStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color.chipBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    func emptySelectorText(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(Color.labelSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
    }
}
