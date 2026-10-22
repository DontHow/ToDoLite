import XCTest
@testable import TodoLite

final class BackupAndMergeTests: XCTestCase {
    private func filesystem() async throws -> (FileSystemManager, URL) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let fs = FileSystemManager(documentsURL: root)
        try await fs.setupDirectories()
        return (fs, root.appendingPathComponent("TodoLite"))
    }

    func testEncodedBackupAtLimitCanBeImportedAndOneByteLessIsRejected() async throws {
        let backup = TodoBackup(todos: [TodoItem(title: "备份大小边界")], projects: [], tags: [], focusSets: [], deletedTodos: [])
        let data = try BackupCoding.encode(backup)
        XCTAssertEqual(try BackupCoding.encode(backup, maximumBytes: data.count), data)
        XCTAssertThrowsError(try BackupCoding.encode(backup, maximumBytes: data.count - 1)) { error in
            guard case RecoveryError.backupTooLarge = error else { return XCTFail("wrong error: \(error)") }
        }
        let (fs, _) = try await filesystem()
        let report = try await RecoveryRepository(fs: fs).importData(data)
        XCTAssertEqual(report.imported, 1)
    }

    func testDirectImportRejectsOversizedDataBeforeDecodingOrWriting() async throws {
        let (fs, _) = try await filesystem()
        do {
            _ = try await RecoveryRepository(fs: fs).importData(Data(count: BackupCoding.maximumBytes + 1))
            XCTFail("oversized import accepted")
        } catch RecoveryError.backupTooLarge { }
        let tasks = try await TodoRepository(fs: fs).listAll()
        XCTAssertTrue(tasks.isEmpty)
    }

    func testExportAndFileImportShareTheSameSizeLimit() async throws {
        let (fs, root) = try await filesystem()
        let url = root.appendingPathComponent("tasks/task_large.json")
        XCTAssertTrue(FileManager.default.createFile(atPath: url.path, contents: nil))
        let handle = try FileHandle(forWritingTo: url)
        try handle.truncate(atOffset: UInt64(BackupCoding.maximumBytes + 1))
        try handle.close()
        let repo = RecoveryRepository(fs: fs)
        do { _ = try await repo.exportData(); XCTFail("oversized export accepted") }
        catch RecoveryError.backupTooLarge { }
        do { _ = try await repo.readBackupFile(at: url); XCTFail("oversized file accepted") }
        catch RecoveryError.backupTooLarge { }
    }

    func testExportRejectsFilenameAndRecordIDMismatch() async throws {
        let (fs, _) = try await filesystem()
        try await fs.write(TodoItem(id: "different", title: "错位文件"), filename: "task_expected.json", directory: .tasks)
        do { _ = try await RecoveryRepository(fs: fs).exportData(); XCTFail("mismatch accepted") }
        catch FileSystemError.invalidFile(let name) { XCTAssertEqual(name, "task_expected.json") }
    }

    func testExportDoesNotMixVersionsOfCoordinatedFilePair() async throws {
        let (fs, root) = try await filesystem()
        let first = TodoItem(id: "first", title: "关联文件 A")
        let second = TodoItem(id: "second", title: "关联文件 B")
        try await fs.write(first, filename: "task_first.json", directory: .tasks)
        try await fs.write(second, filename: "task_second.json", directory: .tasks)
        let writer = Task.detached {
            for version in 2...20 {
                var a = first
                var b = second
                a.version = version
                b.version = version
                var coordinationError: NSError?
                var result: Result<Void, Error>?
                NSFileCoordinator().coordinate(writingItemAt: root.appendingPathComponent("tasks/task_first.json"), options: [],
                                               writingItemAt: root.appendingPathComponent("tasks/task_second.json"), options: [], error: &coordinationError) { aURL, bURL in
                    result = Result {
                        try JSONEncoder().encode(a).write(to: aURL, options: .atomic)
                        try JSONEncoder().encode(b).write(to: bURL, options: .atomic)
                    }
                }
                if let coordinationError { throw coordinationError }
                try XCTUnwrap(result).get()
            }
        }
        let repo = RecoveryRepository(fs: fs)
        for _ in 0..<10 {
            let data = try await repo.exportData()
            let backup = try JSONDecoder().decode(TodoBackup.self, from: data)
            XCTAssertEqual(backup.todos.count, 2)
            XCTAssertEqual(Set(backup.todos.map(\.version)).count, 1)
        }
        try await writer.value
    }

    @MainActor
    func testRepeatedNotificationsDoNotDuplicateCreatedRecords() async throws {
        let (fs, _) = try await filesystem()
        let store = TodoStore(fs: fs)
        let draft = TodoItem(title: "并发通知和保存")
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { _ = try await store.saveDraft(draft, creating: true, projectName: "项目", tagNames: ["标签"]) }
            for _ in 0..<10 {
                group.addTask { await store.refreshRecordFromDisk(id: draft.id, directory: "tasks") }
            }
            try await group.waitForAll()
        }
        await store.refreshRecordFromDisk(id: draft.id, directory: "tasks")
        XCTAssertEqual(store.todos.map(\.id), [draft.id])
        let project = try XCTUnwrap(store.projects.first)
        let tag = try XCTUnwrap(store.tags.first)
        for _ in 0..<3 {
            await store.refreshRecordFromDisk(id: project.id, directory: "projects")
            await store.refreshRecordFromDisk(id: tag.id, directory: "tags")
        }
        XCTAssertEqual(store.projects.count, 1)
        XCTAssertEqual(store.tags.count, 1)
    }

    @MainActor
    func testStaleRemovalNotificationsRetainRecordsThatStillExist() async throws {
        let (fs, _) = try await filesystem()
        let store = TodoStore(fs: fs)
        let task = try await TodoRepository(fs: fs).create(TodoItem(title: "保留任务"))
        let project = try await ProjectRepository(fs: fs).create(Project(name: "保留项目"))
        let tag = try await TagRepository(fs: fs).create(TagItem(name: "保留标签"))
        // removal 通知现在也重新读取磁盘，而不是直接清空内存。
        await store.refreshRecordFromDisk(id: task.id, directory: "tasks")
        await store.refreshRecordFromDisk(id: project.id, directory: "projects")
        await store.refreshRecordFromDisk(id: tag.id, directory: "tags")
        XCTAssertEqual(store.todos, [task])
        XCTAssertEqual(store.projects, [project])
        XCTAssertEqual(store.tags, [tag])
        try await fs.delete(filename: "task_\(task.id).json", directory: .tasks)
        try await fs.delete(filename: "project_\(project.id).json", directory: .projects)
        try await fs.delete(filename: "tag_\(tag.id).json", directory: .tags)
        await store.refreshRecordFromDisk(id: task.id, directory: "tasks")
        await store.refreshRecordFromDisk(id: project.id, directory: "projects")
        await store.refreshRecordFromDisk(id: tag.id, directory: "tags")
        XCTAssertTrue(store.todos.isEmpty)
        XCTAssertTrue(store.projects.isEmpty)
        XCTAssertTrue(store.tags.isEmpty)
    }

    @MainActor
    func testTagRefreshUsesCurrentDiskInsteadOfStaleMemory() async throws {
        let (fs, _) = try await filesystem()
        let repo = TagRepository(fs: fs)
        let original = try await repo.create(TagItem(name: "原标签"))
        let store = TodoStore(fs: fs)
        store.tags = [original]
        var changed = original
        changed.name = "最新标签"
        _ = try await repo.save(changed, replacing: original)
        await store.refreshRecordFromDisk(id: original.id, directory: "tags")
        XCTAssertEqual(store.tags.first?.name, "最新标签")
    }

    @MainActor
    func testUnreadableRefreshKeepsKnownRecordAndReportsError() async throws {
        let (fs, _) = try await filesystem()
        let task = try await TodoRepository(fs: fs).create(TodoItem(title: "保留界面快照"))
        let store = TodoStore(fs: fs)
        store.todos = [task]
        try await fs.write(["bad": true], filename: "task_\(task.id).json", directory: .tasks)
        await store.refreshRecordFromDisk(id: task.id, directory: "tasks")
        XCTAssertEqual(store.todos, [task])
        XCTAssertNotNil(store.operationError)
    }

    @MainActor
    func testBulkLoadDoesNotOverwriteMutationCompletedDuringLoad() async throws {
        let (fs, _) = try await filesystem()
        let started = expectation(description: "bulk load waiting for config")
        let gate = GatedAPIKeyStorage(started: started)
        let store = TodoStore(fs: fs, keyStorage: gate)
        let loading = Task { @MainActor in try await store.loadAll() }
        defer { gate.release.signal() }
        await fulfillment(of: [started], timeout: 5)
        try await store.createTodo(title: "加载期间新建")
        gate.release.signal()
        try await loading.value
        XCTAssertEqual(store.todos.map(\.title), ["加载期间新建"])
    }
}

private final class GatedAPIKeyStorage: APIKeyStorage, @unchecked Sendable {
    private let lock = NSLock()
    private var shouldWait = true
    private let started: XCTestExpectation
    let release = DispatchSemaphore(value: 0)
    init(started: XCTestExpectation) { self.started = started }
    func load() throws -> String? {
        lock.lock()
        let wait = shouldWait
        shouldWait = false
        lock.unlock()
        if wait {
            started.fulfill()
            _ = release.wait(timeout: .now() + 10)
        }
        return nil
    }
    func save(_ value: String) throws { }
}
