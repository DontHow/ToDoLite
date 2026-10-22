import XCTest
@testable import TodoLite

final class ConsistencyTests: XCTestCase {
    private func filesystem() async throws -> (FileSystemManager, URL) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let fs = FileSystemManager(documentsURL: root)
        try await fs.setupDirectories()
        return (fs, root.appendingPathComponent("TodoLite"))
    }

    func testConcurrentFocusAddsAcrossIndependentFileActorsKeepAllIDs() async throws {
        let (fs, root) = try await filesystem()
        let first = FocusRepository(fs: fs)
        let second = FocusRepository(fs: FileSystemManager(documentsURL: root.deletingLastPathComponent()))
        try await withThrowingTaskGroup(of: Void.self) { group in
            for index in 0..<20 {
                group.addTask {
                    _ = try await (index.isMultiple(of: 2) ? first : second)
                        .setFocused(true, id: "task-\(index)")
                }
            }
            try await group.waitForAll()
        }
        let saved = try await first.load()
        XCTAssertEqual(Set(saved.taskIds), Set((0..<20).map { "task-\($0)" }))
        XCTAssertEqual(saved.taskIds.count, 20)
    }

    func testFocusRemovalPreservesOtherChangesAndDeduplicates() async throws {
        let (fs, root) = try await filesystem()
        let first = FocusRepository(fs: fs)
        let second = FocusRepository(fs: FileSystemManager(documentsURL: root.deletingLastPathComponent()))
        try await first.save(FocusSet(taskIds: ["keep", "keep", "remove"]))
        async let add = first.setFocused(true, id: "new")
        async let remove = second.setFocused(false, id: "remove")
        _ = try await (add, remove)
        let saved = try await first.load()
        XCTAssertEqual(Set(saved.taskIds), Set(["keep", "new"]))
        XCTAssertEqual(saved.taskIds.count, 2)
        _ = try await first.setFocused(true, id: "new")
        let repeated = try await first.load()
        XCTAssertEqual(repeated.taskIds, saved.taskIds)
    }

    @MainActor
    func testStoreFocusUsesTodayInsteadOfStaleYesterdaySnapshot() async throws {
        let (fs, _) = try await filesystem()
        let yesterday = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: -1, to: Date()))
        let previous = FocusSet(date: FocusSet.todayString(for: yesterday), taskIds: ["yesterday"])
        try await FocusRepository(fs: fs).save(previous)
        try await FocusRepository(fs: fs).save(FocusSet(taskIds: ["external"]))
        let store = TodoStore(fs: fs)
        store.focusSet = previous
        try await store.addToFocus(id: "today")
        XCTAssertEqual(store.focusSet.date, FocusSet.todayString())
        XCTAssertEqual(store.focusSet.taskIds, ["external", "today"])
        let historical = try await FocusRepository(fs: fs).load(for: yesterday)
        XCTAssertEqual(historical.taskIds, ["yesterday"])
        // 即使内存没有这个 ID，也必须从实际磁盘列表移除。
        store.focusSet = FocusSet()
        try await store.removeFromFocus(id: "external")
        XCTAssertEqual(store.focusSet.taskIds, ["today"])
    }

    @MainActor
    func testConcurrentStoreFocusOperationsPublishPersistedSnapshot() async throws {
        let (fs, _) = try await filesystem()
        let store = TodoStore(fs: fs)
        try await withThrowingTaskGroup(of: Void.self) { group in
            for index in 0..<10 {
                group.addTask { try await store.addToFocus(id: "task-\(index)") }
            }
            try await group.waitForAll()
        }
        let saved = try await FocusRepository(fs: fs).load()
        XCTAssertEqual(store.focusSet.taskIds, saved.taskIds)
        XCTAssertEqual(saved.taskIds.count, 10)
    }

    func testFocusDateMismatchAndCorruptionAreNotOverwritten() async throws {
        let (fs, root) = try await filesystem()
        let repo = FocusRepository(fs: fs)
        let filename = FocusRepository.filename(for: Date())
        try await fs.write(FocusSet(date: "2000-01-01", taskIds: ["keep"]), filename: filename, directory: .meta)
        do { _ = try await repo.setFocused(true, id: "new"); XCTFail("mismatched date must fail") }
        catch FileSystemError.invalidFile { }
        let untouched = try await fs.read(FocusSet.self, filename: filename, directory: .meta)
        XCTAssertEqual(untouched.taskIds, ["keep"])
        let bytes = Data("corrupt focus".utf8)
        let url = root.appendingPathComponent("meta/\(filename)")
        try bytes.write(to: url)
        do { _ = try await repo.setFocused(false, id: "keep"); XCTFail("corruption must fail") }
        catch FileSystemError.invalidFile { }
        XCTAssertEqual(try Data(contentsOf: url), bytes)
    }

    func testConcurrentProjectEditsKeepWinnerAndBackupLoser() async throws {
        let (fs, root) = try await filesystem()
        let first = ProjectRepository(fs: fs)
        let second = ProjectRepository(fs: FileSystemManager(documentsURL: root.deletingLastPathComponent()))
        let original = try await first.create(Project(name: "原项目"))
        let outcomes = await withTaskGroup(of: Bool.self, returning: [Bool].self) { group in
            for index in 0..<2 {
                group.addTask {
                    var edited = original
                    edited.name = "编辑-\(index)"
                    do {
                        _ = try await (index == 0 ? first : second).save(edited, replacing: original)
                        return true
                    } catch { return false }
                }
            }
            var results: [Bool] = []
            for await result in group { results.append(result) }
            return results
        }
        XCTAssertEqual(outcomes.filter { $0 }.count, 1)
        let saved = try await first.read(id: original.id)
        let backups = try await fs.listFiles(in: .conflicts)
        XCTAssertEqual(backups.count, 1)
        let backup = try await fs.read(Project.self, filename: XCTUnwrap(backups.first), directory: .conflicts)
        XCTAssertNotEqual(backup.name, saved.name)
    }

    func testTagEditRequiresOriginalSnapshotAndBacksUpConflict() async throws {
        let (fs, _) = try await filesystem()
        let repo = TagRepository(fs: fs)
        let original = try await repo.create(TagItem(name: "原标签"))
        var newer = original
        newer.colorHex = "#123456"
        _ = try await repo.save(newer, replacing: original)
        var stale = original
        stale.name = "过期编辑"
        do { _ = try await repo.save(stale, replacing: original); XCTFail("stale edit accepted") }
        catch FileSystemError.conflictDetected { }
        let saved = try await repo.read(id: original.id)
        XCTAssertEqual(saved, newer)
        let backups = try await fs.listFiles(in: .conflicts)
        let backup = try await fs.read(TagItem.self, filename: XCTUnwrap(backups.first), directory: .conflicts)
        XCTAssertEqual(backup, stale)
    }

    func testDeletedProjectAndTagCannotBeRecreatedByOldEditors() async throws {
        let (fs, _) = try await filesystem()
        let projects = ProjectRepository(fs: fs)
        let tags = TagRepository(fs: fs)
        let project = try await projects.create(Project(name: "已删除"))
        let tag = try await tags.create(TagItem(name: "已删除"))
        try await projects.delete(id: project.id)
        try await tags.delete(id: tag.id)
        do { _ = try await projects.save(project, replacing: project); XCTFail("project resurrected") }
        catch FileSystemError.fileNotFound { }
        do { _ = try await tags.save(tag, replacing: tag); XCTFail("tag resurrected") }
        catch FileSystemError.fileNotFound { }
        let remainingProjects = try await projects.listAll()
        let remainingTags = try await tags.listAll()
        XCTAssertTrue(remainingProjects.isEmpty)
        XCTAssertTrue(remainingTags.isEmpty)
    }

    func testMetadataCreateCannotOverwriteExistingID() async throws {
        let (fs, _) = try await filesystem()
        let projects = ProjectRepository(fs: fs)
        let tags = TagRepository(fs: fs)
        let project = try await projects.create(Project(name: "保留项目"))
        let tag = try await tags.create(TagItem(name: "保留标签"))
        do { _ = try await projects.create(Project(id: project.id, name: "覆盖")); XCTFail("duplicate create") }
        catch FileSystemError.conflictDetected { }
        do { _ = try await tags.create(TagItem(id: tag.id, name: "覆盖")); XCTFail("duplicate create") }
        catch FileSystemError.conflictDetected { }
        let savedProject = try await projects.read(id: project.id)
        let savedTag = try await tags.read(id: tag.id)
        XCTAssertEqual(savedProject, project)
        XCTAssertEqual(savedTag, tag)
    }
}
