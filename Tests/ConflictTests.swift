import XCTest
@testable import TodoLite

final class ConflictTests: XCTestCase {
    private func filesystem() async throws -> (FileSystemManager, URL) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let fs = FileSystemManager(documentsURL: root)
        try await fs.setupDirectories()
        return (fs, root.appendingPathComponent("TodoLite"))
    }

    private func taskConflict(_ fs: FileSystemManager, task: TodoItem) async throws -> ConflictRecord {
        let record = ConflictRecord(filename: "task_\(task.id)_conflict_fixture.json", payload: .todo(task))
        _ = try await ConflictRepository(fs: fs).importRecord(record)
        return record
    }

    func testTaskRestoreCreatesIndependentCopyAndRetryPreservesLaterEdit() async throws {
        let (fs, _) = try await filesystem()
        let repo = TodoRepository(fs: fs)
        let completed = Date(timeIntervalSince1970: 1000)
        let current = try await repo.create(TodoItem(title: "当前任务"))
        var older = current
        older.title = "冲突内容"
        older.status = .done
        older.completedAt = completed
        older.dueAt = completed
        let record = try await taskConflict(fs, task: older)
        let recovery = ConflictRepository(fs: fs)
        let copied = try await recovery.restoreAsCopy(record)
        XCTAssertNotEqual(copied.id, current.id)
        var actual = try await repo.read(id: copied.id)
        XCTAssertEqual(actual.title, "冲突内容（冲突副本）")
        XCTAssertEqual(actual.status, .done)
        XCTAssertEqual(actual.completedAt, completed)
        XCTAssertEqual(actual.dueAt, completed)
        actual.title = "恢复后继续编辑"
        let edited = try await repo.save(actual)
        let retry = try await recovery.restoreAsCopy(record)
        XCTAssertEqual(retry.id, copied.id)
        let unchanged = try await repo.read(id: copied.id)
        let original = try await repo.read(id: current.id)
        XCTAssertEqual(unchanged, edited)
        XCTAssertEqual(original, current)
        let records = try await recovery.listAll()
        XCTAssertEqual(records, [record])
    }

    func testRestoringDeletedCopyInvalidatesItsOldEditor() async throws {
        let (fs, _) = try await filesystem()
        let record = try await taskConflict(fs, task: TodoItem(title: "重复恢复"))
        let recovery = ConflictRepository(fs: fs)
        let copy = try await recovery.restoreAsCopy(record)
        let repo = TodoRepository(fs: fs)
        let old = try await repo.read(id: copy.id)
        try await repo.delete(id: copy.id)
        _ = try await recovery.restoreAsCopy(record)
        let restored = try await repo.read(id: copy.id)
        XCTAssertGreaterThan(restored.version, old.version)
        do { _ = try await repo.save(old); XCTFail("old editor overwrote recovered copy") }
        catch FileSystemError.conflictDetected { }
    }

    func testProjectAndTagRestorePreserveAppearanceWithoutChangingOriginals() async throws {
        let (fs, _) = try await filesystem()
        let project = try await ProjectRepository(fs: fs).create(Project(name: "原项目", emoji: "📚", colorHex: "#123456"))
        let tag = try await TagRepository(fs: fs).create(TagItem(name: "原标签", colorHex: "#654321"))
        let projectRecord = ConflictRecord(filename: "project_\(project.id)_conflict_fixture.json", payload: .project(project))
        let tagRecord = ConflictRecord(filename: "tag_\(tag.id)_conflict_fixture.json", payload: .tag(tag))
        let recovery = ConflictRepository(fs: fs)
        _ = try await recovery.importRecord(projectRecord)
        _ = try await recovery.importRecord(tagRecord)
        let projectCopy = try await recovery.restoreAsCopy(projectRecord)
        let tagCopy = try await recovery.restoreAsCopy(tagRecord)
        let newProject = try await ProjectRepository(fs: fs).read(id: projectCopy.id)
        let newTag = try await TagRepository(fs: fs).read(id: tagCopy.id)
        XCTAssertNotEqual(newProject.id, project.id)
        XCTAssertNotEqual(newTag.id, tag.id)
        XCTAssertEqual(newProject.emoji, project.emoji)
        XCTAssertEqual(newProject.colorHex, project.colorHex)
        XCTAssertEqual(newTag.colorHex, tag.colorHex)
        let originalProject = try await ProjectRepository(fs: fs).read(id: project.id)
        let originalTag = try await TagRepository(fs: fs).read(id: tag.id)
        XCTAssertEqual(originalProject, project)
        XCTAssertEqual(originalTag, tag)
    }

    func testChangedConflictMustBeReviewedAgainBeforeRestore() async throws {
        let (fs, _) = try await filesystem()
        let source = TodoItem(title: "查看时的内容")
        let reviewed = try await taskConflict(fs, task: source)
        var changed = source
        changed.title = "查看后变化"
        try await fs.write(changed, filename: reviewed.filename, directory: .conflicts)
        do { _ = try await ConflictRepository(fs: fs).restoreAsCopy(reviewed); XCTFail("stale preview accepted") }
        catch ConflictRecoveryError.changed { }
        let tasks = try await TodoRepository(fs: fs).listAll()
        XCTAssertTrue(tasks.isEmpty)
    }

    func testVersionTwoBackupRoundTripsAllSupportedConflictsAndExcludesConfig() async throws {
        let (fs, _) = try await filesystem()
        let repo = ConflictRepository(fs: fs)
        let task = TodoItem(title: "任务冲突")
        let project = Project(name: "项目冲突")
        let tag = TagItem(name: "标签冲突")
        let records = [
            ConflictRecord(filename: "task_\(task.id)_conflict_fixture.json", payload: .todo(task)),
            ConflictRecord(filename: "project_\(project.id)_conflict_fixture.json", payload: .project(project)),
            ConflictRecord(filename: "tag_\(tag.id)_conflict_fixture.json", payload: .tag(tag))
        ]
        for record in records { _ = try await repo.importRecord(record) }
        try await fs.write(["apiKey": "conflict-secret-sentinel"], filename: "llm_config_conflict_fixture.json", directory: .conflicts)
        let data = try await RecoveryRepository(fs: fs).exportData()
        let decoded = try JSONDecoder().decode(TodoBackup.self, from: data)
        XCTAssertEqual(decoded.version, 2)
        XCTAssertEqual(Set(decoded.conflicts.map(\.filename)), Set(records.map(\.filename)))
        XCTAssertFalse(String(decoding: data, as: UTF8.self).contains("conflict-secret-sentinel"))
        let (destination, _) = try await filesystem()
        let report = try await RecoveryRepository(fs: destination).importData(data)
        XCTAssertEqual(report.imported, 3)
        let restored = try await ConflictRepository(fs: destination).listAll()
        XCTAssertEqual(restored, records.sorted { $0.filename < $1.filename })
        let retry = try await RecoveryRepository(fs: destination).importData(data)
        XCTAssertEqual(retry.imported, 0)
        XCTAssertEqual(retry.skipped, 3)
    }

    func testLegacyVersionOneBackupWithoutConflictFieldStillImports() async throws {
        let (fs, _) = try await filesystem()
        let task = TodoItem(title: "旧备份")
        var backup = TodoBackup(todos: [task], projects: [], tags: [], focusSets: [], deletedTodos: [])
        backup.version = 1
        let encoded = try JSONEncoder().encode(backup)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: "conflicts")
        let legacy = try JSONSerialization.data(withJSONObject: object)
        let result = try await RecoveryRepository(fs: fs).importData(legacy)
        XCTAssertEqual(result.imported, 1)
        let actual = try await TodoRepository(fs: fs).read(id: task.id)
        XCTAssertEqual(actual, task)
    }

    func testInvalidConflictNamesRejectEntireImportBeforeWritingMetadata() async throws {
        let (fs, _) = try await filesystem()
        let item = TodoItem(id: "safe", title: "路径保护")
        for filename in ["../task_safe_conflict_fixture.json", "task_different_conflict_fixture.json", "llm_config_conflict_fixture.json"] {
            let conflict = ConflictRecord(filename: filename, payload: .todo(item))
            let backup = TodoBackup(todos: [], projects: [Project(name: "不可提前写入")], tags: [], focusSets: [], deletedTodos: [], conflicts: [conflict])
            do { _ = try await RecoveryRepository(fs: fs).importData(JSONEncoder().encode(backup)); XCTFail("invalid conflict accepted") }
            catch RecoveryError.invalidBackup { }
        }
        let projects = try await ProjectRepository(fs: fs).listAll()
        XCTAssertTrue(projects.isEmpty)
    }

    func testImportKeepsExistingConflictWithSameFilename() async throws {
        let (fs, _) = try await filesystem()
        let task = TodoItem(title: "当前冲突副本")
        let current = try await taskConflict(fs, task: task)
        var different = task
        different.title = "备份中的其他内容"
        let incoming = ConflictRecord(filename: current.filename, payload: .todo(different))
        let backup = TodoBackup(todos: [], projects: [], tags: [], focusSets: [], deletedTodos: [], conflicts: [incoming])
        let result = try await RecoveryRepository(fs: fs).importData(JSONEncoder().encode(backup))
        XCTAssertEqual(result.skipped, 1)
        let preserved = try await ConflictRepository(fs: fs).listAll()
        XCTAssertEqual(preserved, [current])
    }

    func testCorruptConflictIsReportedAndPreserved() async throws {
        let (fs, root) = try await filesystem()
        let name = "task_safe_conflict_fixture.json"
        let bytes = Data("corrupt".utf8)
        let url = root.appendingPathComponent("conflicts/\(name)")
        try bytes.write(to: url)
        do { _ = try await ConflictRepository(fs: fs).listAll(); XCTFail("corruption hidden") }
        catch FileSystemError.invalidFile { }
        XCTAssertEqual(try Data(contentsOf: url), bytes)
    }

    func testConflictPlaceholderBlocksIncompleteBackup() async throws {
        let (fs, root) = try await filesystem()
        let placeholder = root.appendingPathComponent("conflicts/.task_safe_conflict_fixture.json.icloud")
        try Data().write(to: placeholder)
        do { _ = try await RecoveryRepository(fs: fs).exportData(); XCTFail("missing conflict omitted") }
        catch FileSystemError.downloadPending { }
        XCTAssertTrue(FileManager.default.fileExists(atPath: placeholder.path))
    }
}
