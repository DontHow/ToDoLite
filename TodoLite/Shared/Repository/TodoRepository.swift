import Foundation

actor TodoRepository {
    static let shared = TodoRepository()

    private let fs = FileSystemManager.shared

    // MARK: - CRUD

    func save(_ item: TodoItem) async throws {
        let filename = filename(for: item.id)

        // Conflict detection: read existing, check version
        if let existing = try? await read(id: item.id) {
            guard item.version > existing.version else {
                // Version not higher — possible conflict
                let data = try JSONEncoder().encode(item)
                try await fs.writeConflictBackup(filename: filename, data: data)
                throw FileSystemError.conflictDetected
            }
        }

        var updated = item
        updated.version += 1
        updated.updatedAt = Date()

        try await fs.write(updated, filename: filename, directory: .tasks)
    }

    func read(id: String) async throws -> TodoItem {
        let filename = filename(for: id)
        return try await fs.read(TodoItem.self, filename: filename, directory: .tasks)
    }

    func delete(id: String) async throws {
        let filename = filename(for: id)
        try await fs.delete(filename: filename, directory: .tasks)
    }

    func listAll() async throws -> [TodoItem] {
        let files = try await fs.listFiles(in: .tasks)
        var items: [TodoItem] = []
        for file in files where file.hasSuffix(".json") {
            if let item = try? await fs.read(TodoItem.self, filename: file, directory: .tasks) {
                items.append(item)
            }
        }
        return items
    }

    // MARK: - Archive

    func archive(_ item: TodoItem) async throws {
        var archived = item
        archived.status = .archived
        archived.updatedAt = Date()
        try await save(archived)
    }

    // MARK: - Helpers

    private func filename(for id: String) -> String {
        "task_\(id).json"
    }
}
