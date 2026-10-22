import XCTest
@testable import TodoLite

final class RecoveryTests: XCTestCase {
    private func filesystem() async throws -> (FileSystemManager, URL) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let fs = FileSystemManager(documentsURL: root)
        try await fs.setupDirectories()
        return (fs, root.appendingPathComponent("TodoLite"))
    }

    func testDeleteAndRestorePreservesHistoryAndRejectsStaleEditor() async throws {
        let (fs, _) = try await filesystem()
        let repo = TodoRepository(fs: fs)
        let completed = Date(timeIntervalSince1970: 1000)
        let saved = try await repo.create(TodoItem(title: "可恢复", status: .done, dueAt: completed, completedAt: completed))
        try await repo.delete(id: saved.id)
        do { _ = try await repo.read(id: saved.id); XCTFail("deleted task should be absent") }
        catch FileSystemError.fileNotFound { }
        let recovery = RecoveryRepository(fs: fs)
        let trash = try await recovery.listTrash()
        XCTAssertEqual(trash.count, 1)
        XCTAssertEqual(trash.first?.todo, saved)
        try await recovery.restore(XCTUnwrap(trash.first))
        let restored = try await repo.read(id: saved.id)
        XCTAssertEqual(restored.status, .done)
        XCTAssertEqual(restored.dueAt, completed)
        XCTAssertEqual(restored.completedAt, completed)
        XCTAssertEqual(restored.version, saved.version + 1)
        let after = try await recovery.listTrash()
        XCTAssertTrue(after.isEmpty)
        do { _ = try await repo.save(saved); XCTFail("stale editor must not overwrite restored task") }
        catch FileSystemError.conflictDetected { }
    }

    func testRestoreDoesNotOverwriteExistingTaskOrRemoveTrash() async throws {
        let (fs, _) = try await filesystem()
        let repo = TodoRepository(fs: fs)
        let original = try await repo.create(TodoItem(title: "原任务"))
        try await repo.delete(id: original.id)
        _ = try await repo.create(TodoItem(id: original.id, title: "当前任务"))
        let recovery = RecoveryRepository(fs: fs)
        let entries = try await recovery.listTrash()
        let entry = try XCTUnwrap(entries.first)
        do { try await recovery.restore(entry); XCTFail("must preserve existing") }
        catch RecoveryError.taskAlreadyExists { }
        let current = try await repo.read(id: original.id)
        XCTAssertEqual(current.title, "当前任务")
        let remaining = try await recovery.listTrash()
        XCTAssertEqual(remaining.count, 1)
    }

    func testTrashWriteFailureKeepsSourceTask() async throws {
        let (fs, root) = try await filesystem()
        let repo = TodoRepository(fs: fs)
        let saved = try await repo.create(TodoItem(title: "不可丢失"))
        let trashURL = root.appendingPathComponent("trash")
        try FileManager.default.removeItem(at: trashURL)
        try Data("not a directory".utf8).write(to: trashURL)
        do { try await repo.delete(id: saved.id); XCTFail("trash write should fail") }
        catch { }
        let preserved = try await repo.read(id: saved.id)
        XCTAssertEqual(preserved, saved)
    }

    func testBackupRoundTripIncludesHistoryTrashAndExcludesSecrets() async throws {
        let (source, _) = try await filesystem()
        let project = Project(name: "项目")
        let tag = TagItem(name: "标签")
        _ = try await ProjectRepository(fs: source).create(project)
        _ = try await TagRepository(fs: source).create(tag)
        let repo = TodoRepository(fs: source)
        let saved = try await repo.create(TodoItem(title: "任务", projectId: project.id, tagIds: [tag.id]))
        let deleted = try await repo.create(TodoItem(title: "已删除"))
        try await repo.delete(id: deleted.id)
        try await FocusRepository(fs: source).save(FocusSet(date: "2024-02-29", taskIds: [saved.id]))
        try await source.write(["apiKey": "secret-sentinel"], filename: "llm_config.json", directory: .config)
        let data = try await RecoveryRepository(fs: source).exportData()
        XCTAssertFalse(String(decoding: data, as: UTF8.self).contains("secret-sentinel"))
        let (destination, _) = try await filesystem()
        let recovery = RecoveryRepository(fs: destination)
        let report = try await recovery.importData(data)
        XCTAssertEqual(report.imported, 5)
        let restored = try await TodoRepository(fs: destination).read(id: saved.id)
        XCTAssertEqual(restored, saved)
        let history = try await destination.read(FocusSet.self, filename: "focus_2024-02-29.json", directory: .meta)
        XCTAssertEqual(history.taskIds, [saved.id])
        let trash = try await recovery.listTrash()
        XCTAssertEqual(trash.first?.todo, deleted)
        let again = try await recovery.importData(data)
        XCTAssertEqual(again.imported, 0)
        XCTAssertEqual(again.skipped, 5)
    }

    func testImportValidatesWholeBackupBeforeAnyWrites() async throws {
        let (fs, _) = try await filesystem()
        for invalid in ["../outside", "a/b", "", ".hidden"] {
            let backup = TodoBackup(todos: [TodoItem(id: invalid, title: "不安全")], projects: [Project(name: "不得提前写入")], tags: [], focusSets: [], deletedTodos: [])
            do {
                _ = try await RecoveryRepository(fs: fs).importData(JSONEncoder().encode(backup))
                XCTFail("invalid identifier accepted")
            } catch RecoveryError.invalidBackup { }
        }
        let projects = try await ProjectRepository(fs: fs).listAll()
        XCTAssertTrue(projects.isEmpty)
        var duplicate = TodoBackup(todos: [], projects: [], tags: [], focusSets: [], deletedTodos: [])
        let item = TodoItem(title: "重复")
        duplicate.todos = [item, item]
        XCTAssertThrowsError(try duplicate.validate())
        duplicate.todos = []
        duplicate.focusSets = [FocusSet(date: "2025-02-30")]
        XCTAssertThrowsError(try duplicate.validate())
        duplicate.focusSets = []
        duplicate.version = 3
        XCTAssertThrowsError(try duplicate.validate())
    }

    func testImportPreservesExistingCorruptFile() async throws {
        let (fs, root) = try await filesystem()
        let corrupt = Data("corrupt".utf8)
        let url = root.appendingPathComponent("tasks/task_existing.json")
        try corrupt.write(to: url)
        let backup = TodoBackup(todos: [TodoItem(id: "existing", title: "备份")], projects: [], tags: [], focusSets: [], deletedTodos: [])
        let report = try await RecoveryRepository(fs: fs).importData(JSONEncoder().encode(backup))
        XCTAssertEqual(report.skipped, 1)
        XCTAssertEqual(try Data(contentsOf: url), corrupt)
    }

    func testPlaceholderBlocksIncompleteExportAndImportOverwrite() async throws {
        let (fs, root) = try await filesystem()
        let placeholder = root.appendingPathComponent("tasks/.task_pending.json.icloud")
        try Data().write(to: placeholder)
        do { _ = try await RecoveryRepository(fs: fs).exportData(); XCTFail("partial export must fail") }
        catch FileSystemError.downloadPending { }
        let backup = TodoBackup(todos: [TodoItem(id: "pending", title: "备份")], projects: [], tags: [], focusSets: [], deletedTodos: [])
        do { _ = try await RecoveryRepository(fs: fs).importData(JSONEncoder().encode(backup)); XCTFail("must not replace placeholder") }
        catch RecoveryError.partialImport { }
        XCTAssertTrue(FileManager.default.fileExists(atPath: placeholder.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("tasks/task_pending.json").path))
    }

    func testInterruptedImportCanResumeWithoutOverwritingCompletedRecords() async throws {
        let (fs, root) = try await filesystem()
        let tag = TagItem(name: "阻塞")
        let placeholder = root.appendingPathComponent("tags/.tag_\(tag.id).json.icloud")
        try Data().write(to: placeholder)
        let project = Project(name: "先恢复")
        let backup = TodoBackup(todos: [TodoItem(title: "最后恢复")], projects: [project], tags: [tag], focusSets: [], deletedTodos: [])
        let data = try JSONEncoder().encode(backup)
        let recovery = RecoveryRepository(fs: fs)
        do { _ = try await recovery.importData(data); XCTFail("must report interruption") }
        catch let RecoveryError.partialImport(report, _) { XCTAssertEqual(report.imported, 1) }
        var edited = project
        edited.name = "中断期间修改"
        _ = try await ProjectRepository(fs: fs).save(edited, replacing: project)
        try FileManager.default.removeItem(at: placeholder)
        let report = try await recovery.importData(data)
        XCTAssertEqual(report.imported, 2)
        XCTAssertEqual(report.skipped, 1)
        let preserved = try await ProjectRepository(fs: fs).read(id: project.id)
        XCTAssertEqual(preserved.name, "中断期间修改")
    }
}
