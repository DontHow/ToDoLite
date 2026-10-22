import Foundation

actor RecoveryRepository {
    private let fs: FileSystemManager

    init(fs: FileSystemManager) { self.fs = fs }

    func listTrash() async throws -> [DeletedTodo] {
        let entries = try await readAll(DeletedTodo.self, directory: .trash, prefix: "deleted_")
        try TodoBackup(todos: [], projects: [], tags: [], focusSets: [], deletedTodos: entries).validate()
        return entries.sorted { $0.deletedAt > $1.deletedAt }
    }

    func restore(_ entry: DeletedTodo) async throws {
        try TodoBackup(todos: [], projects: [], tags: [], focusSets: [], deletedTodos: [entry]).validate()
        // 重新读取磁盘记录，避免使用已经过期的列表快照。
        let current = try await fs.read(DeletedTodo.self, filename: entry.filename, directory: .trash)
        let validation = TodoBackup(todos: [], projects: [], tags: [], focusSets: [], deletedTodos: [current])
        try validation.validate()
        guard current.id == entry.id else { throw RecoveryError.invalidBackup }
        var restored = current.todo.normalizingCompletion()
        restored.version += 1
        restored.updatedAt = Date()
        guard try await fs.insertIfMissing(restored, filename: "task_\(restored.id).json", directory: .tasks) else {
            throw RecoveryError.taskAlreadyExists
        }
        try await fs.delete(filename: entry.filename, directory: .trash)
    }

    func exportData() async throws -> Data {
        for attempt in 0..<3 {
            do {
                let files = try await fs.backupSnapshot()
                var backup = TodoBackup(todos: [], projects: [], tags: [], focusSets: [], deletedTodos: [])
                let decoder = JSONDecoder()
                for file in files {
                    do {
                        switch file.directory {
                        case "tasks":
                            let item = try decoder.decode(TodoItem.self, from: file.data)
                            guard file.filename == "task_\(item.id).json" else { throw RecoveryError.invalidBackup }
                            backup.todos.append(item)
                        case "projects":
                            let item = try decoder.decode(Project.self, from: file.data)
                            guard file.filename == "project_\(item.id).json" else { throw RecoveryError.invalidBackup }
                            backup.projects.append(item)
                        case "tags":
                            let item = try decoder.decode(TagItem.self, from: file.data)
                            guard file.filename == "tag_\(item.id).json" else { throw RecoveryError.invalidBackup }
                            backup.tags.append(item)
                        case "meta":
                            let item = try decoder.decode(FocusSet.self, from: file.data)
                            guard file.filename == "focus_\(item.date).json" else { throw RecoveryError.invalidBackup }
                            backup.focusSets.append(item)
                        case "trash":
                            let item = try decoder.decode(DeletedTodo.self, from: file.data)
                            guard file.filename == item.filename else { throw RecoveryError.invalidBackup }
                            backup.deletedTodos.append(item)
                        case "conflicts":
                            backup.conflicts.append(try ConflictRecord.decode(filename: file.filename, data: file.data))
                        default: break
                        }
                    } catch { throw FileSystemError.invalidFile(file.filename) }
                }
                return try BackupCoding.encode(backup)
            } catch RecoveryError.backupChanged {
                if attempt == 2 { throw RecoveryError.backupChanged }
            }
        }
        throw RecoveryError.backupChanged
    }

    func readBackupFile(at url: URL) throws -> Data {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        var result: Result<Data, Error>?
        var coordinationError: NSError?
        NSFileCoordinator().coordinate(readingItemAt: url, options: .withoutChanges, error: &coordinationError) { coordinated in
            result = Result {
                try BackupCoding.readData(from: coordinated)
            }
        }
        if let coordinationError { throw coordinationError }
        guard let result else { throw FileSystemError.readFailed }
        return try result.get()
    }

    func importData(_ data: Data) async throws -> RecoveryReport {
        try BackupCoding.checkSize(data)
        let backup: TodoBackup
        do {
            backup = try JSONDecoder().decode(TodoBackup.self, from: data)
            try backup.validate()
        } catch { throw RecoveryError.invalidBackup }
        var report = RecoveryReport()
        func count(_ inserted: Bool) {
            if inserted { report.imported += 1 } else { report.skipped += 1 }
        }
        do {
            // 元数据先写入。每条只新增，失败后重试可安全跳过已恢复的文件。
            for item in backup.projects {
                count(try await fs.insertIfMissing(item, filename: "project_\(item.id).json", directory: .projects))
            }
            for item in backup.tags {
                count(try await fs.insertIfMissing(item, filename: "tag_\(item.id).json", directory: .tags))
            }
            for item in backup.todos {
                count(try await fs.insertIfMissing(item, filename: "task_\(item.id).json", directory: .tasks))
            }
            for item in backup.focusSets {
                count(try await fs.insertIfMissing(item, filename: "focus_\(item.date).json", directory: .meta))
            }
            for item in backup.deletedTodos {
                count(try await fs.insertIfMissing(item, filename: item.filename, directory: .trash))
            }
            for item in backup.conflicts {
                count(try await ConflictRepository(fs: fs).importRecord(item))
            }

        } catch { throw RecoveryError.partialImport(report, error.localizedDescription) }
        return report
    }

    private func readAll<T: Decodable & Sendable>(_ type: T.Type, directory: FileDirectory, prefix: String) async throws -> [T] {
        var result: [T] = []
        for filename in try await fs.listFiles(in: directory).sorted()
            where filename.hasPrefix(prefix) && filename.hasSuffix(".json") {
            result.append(try await fs.read(type, filename: filename, directory: directory))
        }
        return result
    }
}
