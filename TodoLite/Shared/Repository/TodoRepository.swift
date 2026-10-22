import Foundation

actor TodoRepository {
    static let shared = TodoRepository()

    private let fs: FileSystemManager

    init(fs: FileSystemManager = .shared) {
        self.fs = fs
    }

    // MARK: - CRUD

    func create(_ item: TodoItem) async throws -> TodoItem {
        try await persist(item, creating: true)
    }

    func validateDraft(_ draft: TodoItem, creating: Bool) async throws {
        do {
            let actual = try await read(id: draft.id)
            guard creating ? Self.matchesCreation(actual, draft: draft) : actual.version == draft.version else {
                throw FileSystemError.conflictDetected
            }
        } catch FileSystemError.fileNotFound {
            if !creating { throw FileSystemError.fileNotFound(filename(for: draft.id)) }
        } catch FileSystemError.conflictDetected {
            try await backupConflict(draft)
            throw FileSystemError.conflictDetected
        }
    }

    private static func matchesCreation(_ actual: TodoItem, draft: TodoItem) -> Bool {
        guard draft.version > 0, draft.version < Int.max else { return false }
        var expected = draft.normalizingCompletion(at: actual.completedAt ?? actual.updatedAt)
        expected.version += 1
        expected.updatedAt = actual.updatedAt
        return actual == expected
    }

    /// 同一草稿已成功写入但调用方尚未收到结果时，重试返回原记录。
    func createRecovering(_ draft: TodoItem) async throws -> TodoItem {
        guard draft.version > 0, draft.version < Int.max else {
            throw FileSystemError.invalidFile(filename(for: draft.id))
        }
        var proposed = draft.normalizingCompletion()
        proposed.version += 1
        proposed.updatedAt = Date()
        do {
            let actual = try await fs.insertOrRead(proposed, filename: filename(for: draft.id), directory: .tasks)
            guard Self.matchesCreation(actual, draft: draft) else { throw FileSystemError.conflictDetected }
            return actual
        } catch FileSystemError.conflictDetected {
            try await backupConflict(draft)
            throw FileSystemError.conflictDetected
        }
    }

    func save(_ item: TodoItem) async throws -> TodoItem {
        try await persist(item, creating: false)
    }

    private func persist(_ item: TodoItem, creating: Bool) async throws -> TodoItem {
        let filename = filename(for: item.id)
        do {
            return try await fs.update(TodoItem.self, filename: filename, directory: .tasks) { existing in
                if creating {
                    guard existing == nil else { throw FileSystemError.conflictDetected }
                } else {
                    guard let existing else { throw FileSystemError.fileNotFound(filename) }
                    guard item.version == existing.version else { throw FileSystemError.conflictDetected }
                }
                var updated = item.normalizingCompletion()
                updated.version += 1
                updated.updatedAt = Date()
                return updated
            }
        } catch FileSystemError.conflictDetected {
            let data = try JSONEncoder().encode(item)
            try await fs.writeConflictBackup(filename: filename, data: data)
            throw FileSystemError.conflictDetected
        }
    }

    func backupConflict(_ todo: TodoItem) async throws {
        try await fs.writeConflictBackup(filename: filename(for: todo.id), data: JSONEncoder().encode(todo))
    }

    func read(id: String) async throws -> TodoItem {
        let filename = filename(for: id)
        return try await fs.read(TodoItem.self, filename: filename, directory: .tasks)
    }

    func delete(id: String) async throws {
        let filename = filename(for: id)
        try await fs.trashTodo(filename: filename)
    }

    func listAll() async throws -> [TodoItem] {
        let files = try await fs.listFiles(in: .tasks)
        var items: [TodoItem] = []
        for file in files where file.hasSuffix(".json") {
            items.append(try await fs.read(TodoItem.self, filename: file, directory: .tasks))
        }
        return items
    }

    // MARK: - Archive

    func archive(_ item: TodoItem) async throws -> TodoItem {
        try await save(item.archived())
    }

    // MARK: - Helpers

    private func filename(for id: String) -> String {
        "task_\(id).json"
    }
}
