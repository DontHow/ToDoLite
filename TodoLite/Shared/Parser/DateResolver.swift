import Foundation

enum DateResolver {
    static func resolve(_ input: String, from base: Date = Date()) -> Date? {
        let lower = input.trimmingCharacters(in: .whitespaces).lowercased()
        let calendar = Calendar.current

        switch lower {
        case "today", "tdy":
            return calendar.startOfDay(for: base)
        case "tomorrow", "tmrw":
            return calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: base))
        case "yesterday":
            return calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: base))
        case "nextweek", "next week", "nw":
            return calendar.date(byAdding: .day, value: 7, to: calendar.startOfDay(for: base))
        case "weekend":
            let todayWeekday = calendar.component(.weekday, from: base)
            let daysToSaturday = (7 - todayWeekday + 7) % 7
            let addDays = daysToSaturday == 0 ? 7 : daysToSaturday
            return calendar.date(byAdding: .day, value: addDays, to: calendar.startOfDay(for: base))
        case "monday", "mon":
            return nextWeekday(2, from: base)
        case "tuesday", "tue":
            return nextWeekday(3, from: base)
        case "wednesday", "wed":
            return nextWeekday(4, from: base)
        case "thursday", "thu":
            return nextWeekday(5, from: base)
        case "friday", "fri":
            return nextWeekday(6, from: base)
        case "saturday", "sat":
            return nextWeekday(7, from: base)
        case "sunday", "sun":
            return nextWeekday(1, from: base)
        default:
            // Try ISO date format: 2026-05-26 or 5/26 or 26/5
            let formats = [
                "yyyy-MM-dd",
                "yyyy/MM/dd",
                "MM/dd",
                "M/d",
                "MM-dd",
                "M-d",
            ]
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            for format in formats {
                formatter.dateFormat = format
                if let date = formatter.date(from: lower) {
                    // For formats without year, assume current year
                    if !format.contains("yyyy") {
                        var components = calendar.dateComponents([.year], from: base)
                        let resolvedComponents = calendar.dateComponents([.month, .day], from: date)
                        components.month = resolvedComponents.month
                        components.day = resolvedComponents.day
                        guard let candidate = calendar.date(from: components) else { return nil }
                        // If candidate is before or equal to base, roll to next year
                        if candidate <= base {
                            components.year = (components.year ?? 0) + 1
                            return calendar.date(from: components)
                        }
                        return candidate
                    }
                    return date
                }
            }
            return nil
        }
    }

    private static func nextWeekday(_ weekday: Int, from date: Date) -> Date? {
        let calendar = Calendar.current
        let todayWeekday = calendar.component(.weekday, from: date)
        let daysToAdd = (weekday - todayWeekday + 7) % 7
        let addDays = daysToAdd == 0 ? 7 : daysToAdd
        return calendar.date(byAdding: .day, value: addDays, to: calendar.startOfDay(for: date))
    }
}
