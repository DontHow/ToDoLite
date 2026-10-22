import Foundation

enum DateResolver {
    static func resolve(_ input: String, from base: Date = Date(), calendar: Calendar = .current) -> Date? {
        let lower = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let today = calendar.startOfDay(for: base)
        switch lower {
        case "today", "tdy", "今天": return today
        case "tomorrow", "tmrw", "明天": return calendar.date(byAdding: .day, value: 1, to: today)
        case "yesterday", "昨天": return calendar.date(byAdding: .day, value: -1, to: today)
        case "nextweek", "next week", "nw", "一周后": return calendar.date(byAdding: .day, value: 7, to: today)
        case "weekend", "周末": return nextWeekday(7, from: base, calendar: calendar)
        case "monday", "mon": return nextWeekday(2, from: base, calendar: calendar)
        case "tuesday", "tue": return nextWeekday(3, from: base, calendar: calendar)
        case "wednesday", "wed": return nextWeekday(4, from: base, calendar: calendar)
        case "thursday", "thu": return nextWeekday(5, from: base, calendar: calendar)
        case "friday", "fri": return nextWeekday(6, from: base, calendar: calendar)
        case "saturday", "sat": return nextWeekday(7, from: base, calendar: calendar)
        case "sunday", "sun": return nextWeekday(1, from: base, calendar: calendar)
        default:
            break
        }

        // 显式验证数字格式和日历组件，禁止 Calendar 自动将 2/30 归一化到三月。
        guard !(lower.contains("-") && lower.contains("/")) else { return nil }
        let parts = lower.split(omittingEmptySubsequences: false, whereSeparator: { $0 == "-" || $0 == "/" })
        guard [2, 3].contains(parts.count),
              parts.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isNumber) }) else { return nil }
        let values = parts.compactMap { Int($0) }
        guard values.count == parts.count else { return nil }
        if parts.count == 3 {
            guard parts[0].count == 4, parts[1].count <= 2, parts[2].count <= 2 else { return nil }
            return validatedDate(year: values[0], month: values[1], day: values[2], calendar: calendar)
        }
        guard parts.allSatisfy({ $0.count <= 2 }) else { return nil }
        let year = calendar.component(.year, from: base)
        // 包含今天；2/29 会查找下一个有效闰年，而不是被默认年份误判为无效。
        for offset in 0...8 {
            if let candidate = validatedDate(year: year + offset, month: values[0], day: values[1], calendar: calendar), candidate >= today {
                return candidate
            }
        }
        return nil
    }

    private static func validatedDate(year: Int, month: Int, day: Int, calendar: Calendar) -> Date? {
        guard year > 0, (1...12).contains(month), (1...31).contains(day),
              let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) else { return nil }
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        guard components.year == year, components.month == month, components.day == day else { return nil }
        return date
    }

    private static func nextWeekday(_ weekday: Int, from date: Date, calendar: Calendar) -> Date? {
        let offset = (weekday - calendar.component(.weekday, from: date) + 7) % 7
        return calendar.date(byAdding: .day, value: offset == 0 ? 7 : offset, to: calendar.startOfDay(for: date))
    }
}
