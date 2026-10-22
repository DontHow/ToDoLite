import Foundation
import CryptoKit

struct ConflictCopy: Sendable {
    var id: String
    var directory: String
}

actor ConflictRepository {
    private let fs: FileSystemManager
    init(fs: FileSystemManager) { self.fs = fs }

    func listAll() async throws -> [ConflictRecord] {
        var result: [ConflictRecord] = []
        for filename in try await fs.listFiles(in: .conflicts).sorted() where ConflictRecord.supports(filename) {
            result.append(try await read(filename: filename))
        }
        return result
    }

    private func read(filename: String) async throws -> ConflictRecord {
        // 调用方的文件名必须先经 validate；列表入口只使用文件系统枚举的名称。
        let payload: ConflictPayload
        if filename.hasPrefix("task_") {
            payload = .todo(try await fs.read(TodoItem.self, filename: filename, directory: .conflicts))
        } else if filename.hasPrefix("project_") {
            payload = .project(try await fs.read(Project.self, filename: filename, directory: .conflicts))
        } else if filename.hasPrefix("tag_") {
            payload = .tag(try await fs.read(TagItem.self, filename: filename, directory: .conflicts))
        } else { throw RecoveryError.invalidBackup }
        let record = ConflictRecord(filename: filename, payload: payload)
        try record.validate()
        return record
    }

    func restoreAsCopy(_ reviewed: ConflictRecord) async throws -> ConflictCopy {
        try reviewed.validate()
        let current = try await read(filename: reviewed.filename)
        guard current == reviewed else { throw ConflictRecoveryError.changed }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let digest = SHA256.hash(data: try encoder.encode(current)).map { String(format: "%02x", $0) }.joined()
        let newID = "recovered_" + digest
        // 副本 ID 由冲突内容决定；重复点击或中断重试复用同一副本，不覆盖已恢复后的编辑。
        switch current.payload {
        case .todo(let source):
            var copy = source.normalizingCompletion(at: source.updatedAt)
            copy.id = newID
            copy.title += "（冲突副本）"
            let deletedVersions = try await RecoveryRepository(fs: fs).listTrash()
                .filter { $0.todo.id == newID }.map { $0.todo.version }
            if let latest = deletedVersions.max() {
                guard latest < Int.max - 1 else { throw RecoveryError.invalidBackup }
                copy.version = latest + 1
            } else { copy.version = 1 }
            let actual = try await fs.insertOrRead(copy, filename: "task_\(newID).json", directory: .tasks)
            guard actual.id == newID else { throw FileSystemError.invalidFile("task_\(newID).json") }
            return ConflictCopy(id: newID, directory: "tasks")
        case .project(var copy):
            copy.id = newID
            copy.name += "（冲突副本）"
            copy.updatedAt = Date()
            let actual = try await fs.insertOrRead(copy, filename: "project_\(newID).json", directory: .projects)
            guard actual.id == newID else { throw FileSystemError.invalidFile("project_\(newID).json") }
            return ConflictCopy(id: newID, directory: "projects")
        case .tag(var copy):
            copy.id = newID
            copy.name += "（冲突副本）"
            let actual = try await fs.insertOrRead(copy, filename: "tag_\(newID).json", directory: .tags)
            guard actual.id == newID else { throw FileSystemError.invalidFile("tag_\(newID).json") }
            return ConflictCopy(id: newID, directory: "tags")
        }
    }

    func importRecord(_ record: ConflictRecord) async throws -> Bool {
        try record.validate()
        switch record.payload {
        case .todo(let item): return try await fs.insertIfMissing(item, filename: record.filename, directory: .conflicts)
        case .project(let item): return try await fs.insertIfMissing(item, filename: record.filename, directory: .conflicts)
        case .tag(let item): return try await fs.insertIfMissing(item, filename: record.filename, directory: .conflicts)
        }
    }
}

enum ConflictRecoveryError: LocalizedError {
    case changed
    var errorDescription: String? { "冲突副本在查看后发生变化，请返回列表刷新后重新查看。" }
}
