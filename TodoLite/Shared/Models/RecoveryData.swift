import Foundation

struct DeletedTodo: Codable, Identifiable, Sendable {
    var todo: TodoItem
    var deletedAt: Date
    var id: String { "\(todo.id)_\(todo.version)" }
    var filename: String { "deleted_\(id).json" }
}

/// 可移植的业务数据备份。API Key、LLM 配置与可重建的搜索索引不进入备份。
struct TodoBackup: Codable, Sendable {
    var format = "TodoLite.backup"
    var version = 2
    var exportedAt = Date()
    var todos: [TodoItem]
    var projects: [Project]
    var tags: [TagItem]
    var focusSets: [FocusSet]
    var deletedTodos: [DeletedTodo]
    var conflicts: [ConflictRecord] = []

    func validate() throws {
        guard format == "TodoLite.backup", (version == 1 && conflicts.isEmpty) || version == 2 else { throw RecoveryError.invalidBackup }
        func safe(_ value: String) -> Bool {
            !value.isEmpty && value.utf8.count <= 128 && value.unicodeScalars.allSatisfy {
                CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-").contains($0)
            }
        }
        func unique(_ ids: [String]) -> Bool { Set(ids).count == ids.count }
        guard unique(conflicts.map(\.filename)) else { throw RecoveryError.invalidBackup }
        for conflict in conflicts { try conflict.validate() }
        let tasks = todos + deletedTodos.map(\.todo)
        guard tasks.allSatisfy({ safe($0.id) && $0.version > 0 && $0.version < Int.max &&
            ($0.projectId.map(safe) ?? true) && $0.tagIds.allSatisfy(safe) }),
              projects.allSatisfy({ safe($0.id) }), tags.allSatisfy({ safe($0.id) }),
              unique(todos.map(\.id)), unique(projects.map(\.id)), unique(tags.map(\.id)),
              unique(focusSets.map(\.date)), unique(deletedTodos.map(\.id)),
              focusSets.allSatisfy({ Self.validDate($0.date) && $0.taskIds.allSatisfy(safe) }) else {
            throw RecoveryError.invalidBackup
        }
    }

    private enum CodingKeys: String, CodingKey {
        case format, version, exportedAt, todos, projects, tags, focusSets, deletedTodos, conflicts
    }

    private static func validDate(_ value: String) -> Bool {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        guard let date = formatter.date(from: value) else { return false }
        return formatter.string(from: date) == value
    }
}

extension TodoBackup {
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        format = try values.decode(String.self, forKey: .format)
        version = try values.decode(Int.self, forKey: .version)
        exportedAt = try values.decode(Date.self, forKey: .exportedAt)
        todos = try values.decode([TodoItem].self, forKey: .todos)
        projects = try values.decode([Project].self, forKey: .projects)
        tags = try values.decode([TagItem].self, forKey: .tags)
        focusSets = try values.decode([FocusSet].self, forKey: .focusSets)
        deletedTodos = try values.decode([DeletedTodo].self, forKey: .deletedTodos)
        conflicts = try values.decodeIfPresent([ConflictRecord].self, forKey: .conflicts) ?? []
    }
}

struct RecoveryReport: Sendable {
    var imported = 0
    var skipped = 0
    var message: String { "已恢复 \(imported) 条记录，保留并跳过 \(skipped) 条已有记录。" }
}

enum RecoveryError: LocalizedError {
    case backupChanged
    case backupTooLarge
    case invalidBackup
    case taskAlreadyExists
    case partialImport(RecoveryReport, String)

    var errorDescription: String? {
        switch self {
        case .backupChanged: return "导出期间数据发生变化，请稍后重试。"
        case .backupTooLarge: return "备份超过 50 MB，无法导出或导入。"
        case .invalidBackup: return "备份格式不受支持或内容无效，尚未导入任何数据。"
        case .taskAlreadyExists: return "同一任务已存在，已保留当前任务和回收站记录。"
        case let .partialImport(report, reason):
            return "\(report.message) 导入中断：\(reason) 可以重新选择原备份继续恢复。"
        }
    }
}

/// 导出、文件读取和直接导入共用同一大小限制。
enum BackupCoding {
    static let maximumBytes = 50 * 1024 * 1024

    static func encode(_ backup: TodoBackup, maximumBytes: Int = maximumBytes) throws -> Data {
        try backup.validate()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(backup)
        try checkSize(data, maximumBytes: maximumBytes)
        return data
    }

    static func readData(from url: URL, maximumBytes: Int = maximumBytes) throws -> Data {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var result = Data()
        while let chunk = try handle.read(upToCount: min(1024 * 1024, maximumBytes - result.count + 1)), !chunk.isEmpty {
            result.append(chunk)
            try checkSize(result, maximumBytes: maximumBytes)
        }
        return result
    }

    static func checkSize(_ data: Data, maximumBytes: Int = maximumBytes) throws {
        guard data.count <= maximumBytes else { throw RecoveryError.backupTooLarge }
    }
}
