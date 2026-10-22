import Foundation

actor FocusRepository {
    static let shared = FocusRepository()

    private let fs: FileSystemManager

    init(fs: FileSystemManager = .shared) {
        self.fs = fs
    }

    func load(for date: Date = Date()) async throws -> FocusSet {
        let filename = Self.filename(for: date)
        do {
            let value = try await fs.read(FocusSet.self, filename: filename, directory: .meta)
            guard value.date == FocusSet.todayString(for: date) else { throw FileSystemError.invalidFile(filename) }
            return value
        } catch FileSystemError.fileNotFound {
            return FocusSet(date: FocusSet.todayString(for: date), taskIds: [])
        }
    }

    /// 基于磁盘当前列表变更单个 ID，避免并发操作覆盖其他关注项。
    func setFocused(_ focused: Bool, id: String, for date: Date = Date()) async throws -> FocusSet {
        let day = FocusSet.todayString(for: date)
        let filename = Self.filename(for: day)
        return try await fs.update(FocusSet.self, filename: filename, directory: .meta) { existing in
            var result = existing ?? FocusSet(date: day)
            guard result.date == day else { throw FileSystemError.invalidFile(filename) }
            var seen = Set<String>()
            result.taskIds = result.taskIds.filter { seen.insert($0).inserted }
            if focused {
                if !result.taskIds.contains(id) { result.taskIds.append(id) }
            } else {
                result.taskIds.removeAll { $0 == id }
            }
            return result
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
