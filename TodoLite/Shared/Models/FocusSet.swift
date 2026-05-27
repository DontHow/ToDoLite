import Foundation

struct FocusSet: Codable, Sendable {
    var date: String
    var taskIds: [String]

    init(date: String = FocusSet.todayString(), taskIds: [String] = []) {
        self.date = date
        self.taskIds = taskIds
    }

    static func todayString(for date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = Calendar.current.timeZone
        return formatter.string(from: date)
    }
}
