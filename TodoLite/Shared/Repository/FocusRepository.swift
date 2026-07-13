import Foundation

actor FocusRepository {
    static let shared = FocusRepository()

    private let fs = FileSystemManager.shared

    func load(for date: Date = Date()) async -> FocusSet {
        let filename = Self.filename(for: date)
        do {
            return try await fs.read(FocusSet.self, filename: filename, directory: .meta)
        } catch {
            return FocusSet(date: FocusSet.todayString(for: date), taskIds: [])
        }
    }

    func save(_ focusSet: FocusSet) async throws {
        let filename = Self.filename(for: focusSet.date)
        try await fs.write(focusSet, filename: filename, directory: .meta)
    }

    static func filename(for date: Date) -> String {
        "focus_\(FocusSet.todayString(for: date)).json"
    }

    private static func filename(for dateString: String) -> String {
        "focus_\(dateString).json"
    }
}
