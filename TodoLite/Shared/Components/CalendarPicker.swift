import SwiftUI

struct CalendarPicker: View {
    @Binding var selectedDate: Date?

    @State private var displayMonth: Date
    @State private var holidays: [String: HolidayInfo] = [:]

    private let calendar = Calendar.current
    private let weekdays = ["日", "一", "二", "三", "四", "五", "六"]
    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    init(selectedDate: Binding<Date?>) {
        _selectedDate = selectedDate
        _displayMonth = State(initialValue: selectedDate.wrappedValue ?? Date())
    }

    var body: some View {
        VStack(spacing: 12) {
            monthHeader

            weekdayHeader

            dayGrid
        }
        .frame(maxWidth: .infinity)
        .task(id: displayMonthYear) {
            await loadHolidays()
        }
        .onChange(of: selectedDate) { _, newValue in
            if let newValue {
                let newComponents = calendar.dateComponents([.year, .month], from: newValue)
                let currentComponents = calendar.dateComponents([.year, .month], from: displayMonth)
                if newComponents != currentComponents {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        displayMonth = calendar.date(from: newComponents) ?? newValue
                    }
                }
            }
        }
    }

    private var displayMonthYear: Int {
        calendar.component(.year, from: displayMonth)
    }

    private func loadHolidays() async {
        let year = calendar.component(.year, from: displayMonth)
        let result = await HolidayService.shared.load(year: year)
        holidays = result
    }

    private func holiday(for date: Date) -> HolidayInfo? {
        holidays[dateFormatter.string(from: date)]
    }

    private var monthHeader: some View {
        HStack(spacing: 8) {
            Button {
                shiftMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .appFont(.body, weight: .semibold)
                    .foregroundStyle(.primary)
                    .frame(width: 32, height: 32)
                    .background(Color.chipBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)

            Spacer()

            Text(monthYearText)
                .appFont(.headline, weight: .semibold)

            if !isDisplayingCurrentMonth {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        displayMonth = Date()
                    }
                } label: {
                    Text("今")
                        .appFont(.caption, weight: .semibold)
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(Color.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }

            Spacer()

            Button {
                shiftMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .appFont(.body, weight: .semibold)
                    .foregroundStyle(.primary)
                    .frame(width: 32, height: 32)
                    .background(Color.chipBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
    }

    private var isDisplayingCurrentMonth: Bool {
        calendar.isDate(displayMonth, equalTo: Date(), toGranularity: .month)
    }

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(weekdays, id: \.self) { day in
                Text(day)
                    .appFont(.caption, weight: .medium)
                    .foregroundStyle(Color.labelSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var dayGrid: some View {
        let days = daysInDisplayMonth()
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 0) {
            ForEach(days.indices, id: \.self) { index in
                if let date = days[index] {
                    dayCell(date)
                } else {
                    Color.clear
                        .frame(minHeight: 52)
                }
            }
        }
    }

    private func dayCell(_ date: Date) -> some View {
        let isSelected = selectedDate.map { calendar.isDate($0, inSameDayAs: date) } ?? false
        let isToday = calendar.isDateInToday(date)
        let isWeekend = isWeekend(date)
        let dayNumber = calendar.component(.day, from: date)
        let holidayInfo = holiday(for: date)

        return Button {
            selectedDate = date
        } label: {
            ZStack {
                if isSelected {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 36, height: 36)
                }

                VStack(spacing: 0) {
                    Text("\(dayNumber)")
                        .appFont(.body, weight: isSelected || isToday ? .semibold : .regular)
                        .foregroundStyle(dayCellForeground(isSelected: isSelected, isToday: isToday, isWeekend: isWeekend, holiday: holidayInfo))

                    if let holidayInfo {
                        Text(holidayInfo.name)
                            .font(.system(size: 7))
                            .foregroundStyle(holidayInfo.isOffDay ? Color.red.opacity(0.85) : Color.labelSecondary)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 1)
                    } else if isToday && !isSelected {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 4, height: 4)
                            .padding(.top, 1)
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func isWeekend(_ date: Date) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        return weekday == 1 || weekday == 7
    }

    private func dayCellForeground(isSelected: Bool, isToday: Bool, isWeekend: Bool, holiday: HolidayInfo?) -> Color {
        if isSelected { return .white }
        if let holiday {
            return holiday.isOffDay ? .red : .primary
        }
        if isToday { return .accentColor }
        if isWeekend { return Color.red.opacity(0.4) }
        return .primary
    }

    private var monthYearText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年 M月"
        return formatter.string(from: displayMonth)
    }

    private func shiftMonth(by value: Int) {
        displayMonth = calendar.date(byAdding: .month, value: value, to: displayMonth) ?? displayMonth
    }

    private func daysInDisplayMonth() -> [Date?] {
        guard let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: displayMonth)) else {
            return []
        }

        let weekdayOfFirst = calendar.component(.weekday, from: firstOfMonth)
        guard let daysInMonth = calendar.range(of: .day, in: .month, for: displayMonth)?.count else {
            return []
        }

        var days: [Date?] = Array(repeating: nil, count: weekdayOfFirst - 1)

        for day in 1...daysInMonth {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth) {
                days.append(date)
            }
        }

        let remaining = (7 - (days.count % 7)) % 7
        days.append(contentsOf: Array(repeating: nil, count: remaining))

        return days
    }
}
