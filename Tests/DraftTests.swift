import XCTest
@testable import TodoLite

final class DraftTests: XCTestCase {
    private func filesystem() async throws -> (FileSystemManager, URL) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let fs = FileSystemManager(documentsURL: root)
        try await fs.setupDirectories()
        return (fs, root.appendingPathComponent("TodoLite"))
    }

    @MainActor
    func testDraftKeepsIDAndRetryDoesNotDuplicateTaskOrMetadata() async throws {
        let (fs, _) = try await filesystem()
        let store = TodoStore(fs: fs)
        let draft = TodoItem(title: "保存同一草稿", status: .done)
        let first = try await store.saveDraft(draft, creating: true, projectName: "项目", tagNames: ["标签", "标签"])
        let retry = try await store.saveDraft(draft, creating: true, projectName: "项目", tagNames: ["标签", "标签"])
        XCTAssertEqual(first.id, draft.id)
        XCTAssertEqual(first, retry)
        XCTAssertEqual(store.todos.count, 1)
        XCTAssertEqual(store.projects.count, 1)
        XCTAssertEqual(store.tags.count, 1)
        XCTAssertEqual(retry.tagIds.count, 1)
        XCTAssertNotNil(retry.completedAt)
    }

    func testStaleDraftDoesNotCreatePendingMetadata() async throws {
        let (fs, _) = try await filesystem()
        let todos = TodoRepository(fs: fs)
        let original = try await todos.create(TodoItem(title: "原任务"))
        var newer = original
        newer.title = "较新内容"
        _ = try await todos.save(newer)
        do {
            _ = try await DraftRepository(fs: fs).save(original, creating: false, projectName: "不应创建", tagNames: ["不应创建"])
            XCTFail("stale edit must fail before metadata writes")
        } catch FileSystemError.conflictDetected { }
        let projects = try await ProjectRepository(fs: fs).listAll()
        let tags = try await TagRepository(fs: fs).listAll()
        XCTAssertTrue(projects.isEmpty)
        XCTAssertTrue(tags.isEmpty)
    }

    func testDeletedDraftCannotCreateMetadataOrResurrectTask() async throws {
        let (fs, _) = try await filesystem()
        let todos = TodoRepository(fs: fs)
        let original = try await todos.create(TodoItem(title: "删除后编辑"))
        try await todos.delete(id: original.id)
        do {
            _ = try await DraftRepository(fs: fs).save(original, creating: false, projectName: "不应创建", tagNames: ["不应创建"])
            XCTFail("deleted draft must fail")
        } catch FileSystemError.fileNotFound { }
        let projects = try await ProjectRepository(fs: fs).listAll()
        let tags = try await TagRepository(fs: fs).listAll()
        let remaining = try await todos.listAll()
        XCTAssertTrue(projects.isEmpty)
        XCTAssertTrue(tags.isEmpty)
        XCTAssertTrue(remaining.isEmpty)
    }

    func testConcurrentParsedDraftsReuseMetadataAcrossIndependentActors() async throws {
        let (fs, root) = try await filesystem()
        let first = DraftRepository(fs: fs)
        let second = DraftRepository(fs: FileSystemManager(documentsURL: root.deletingLastPathComponent()))
        async let a = first.save(TodoItem(title: "任务 A"), creating: true, projectName: "共享项目", tagNames: ["共享标签"])
        async let b = second.save(TodoItem(title: "任务 B"), creating: true, projectName: "共享项目", tagNames: ["共享标签"])
        let (savedA, savedB) = try await (a, b)
        XCTAssertEqual(savedA.todo.projectId, savedB.todo.projectId)
        XCTAssertEqual(savedA.todo.tagIds, savedB.todo.tagIds)
        let projects = try await ProjectRepository(fs: fs).listAll()
        let tags = try await TagRepository(fs: fs).listAll()
        XCTAssertEqual(projects.count, 1)
        XCTAssertEqual(tags.count, 1)
    }

    func testTaskWriteFailureReportsPreservedMetadataAndRetryReusesIt() async throws {
        let (fs, root) = try await filesystem()
        let draft = TodoItem(title: "失败后重试")
        let tasks = root.appendingPathComponent("tasks")
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: tasks.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: tasks.path) }
        let repo = DraftRepository(fs: fs)
        var projectID: String?
        do {
            _ = try await repo.save(draft, creating: true, projectName: "保留项目", tagNames: ["保留标签"])
            XCTFail("task write should fail")
        } catch let error as DraftSaveError {
            XCTAssertEqual(error.projects.count, 1)
            XCTAssertEqual(error.tags.count, 1)
            projectID = error.projects.first?.id
        }
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: tasks.path)
        let saved = try await repo.save(draft, creating: true, projectName: "保留项目", tagNames: ["保留标签"])
        XCTAssertEqual(saved.todo.projectId, projectID)
        let projects = try await ProjectRepository(fs: fs).listAll()
        let tags = try await TagRepository(fs: fs).listAll()
        let todos = try await TodoRepository(fs: fs).listAll()
        XCTAssertEqual(projects.count, 1)
        XCTAssertEqual(tags.count, 1)
        XCTAssertEqual(todos.map(\.id), [draft.id])
    }

    @MainActor
    func testPartialMetadataFailureIsPublishedAndCanResume() async throws {
        let (fs, root) = try await filesystem()
        let directory = root.appendingPathComponent("tags")
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: directory.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: directory.path) }
        let store = TodoStore(fs: fs)
        let draft = TodoItem(title: "部分元数据写入后重试")
        do {
            _ = try await store.saveDraft(draft, creating: true, projectName: "已保留", tagNames: ["待重试"])
            XCTFail("tag directory is not writable")
        } catch let error as DraftSaveError {
            XCTAssertEqual(error.projects.count, 1)
            XCTAssertEqual(error.tags.count, 0)
        }
        XCTAssertTrue(store.todos.isEmpty)
        XCTAssertEqual(store.projects.count, 1)
        XCTAssertTrue(store.tags.isEmpty)
        let projectID = store.projects.first?.id
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: directory.path)
        let saved = try await store.saveDraft(draft, creating: true, projectName: "已保留", tagNames: ["待重试"])
        XCTAssertEqual(saved.projectId, projectID)
        XCTAssertEqual(store.todos.map(\.id), [draft.id])
        XCTAssertEqual(store.projects.count, 1)
        XCTAssertEqual(store.tags.count, 1)
    }

    func testConcurrentSubmissionOfSameDraftDoesNotCreateDuplicateTask() async throws {
        let (fs, root) = try await filesystem()
        let draft = TodoItem(title: "同一草稿并发提交")
        let first = DraftRepository(fs: fs)
        let second = DraftRepository(fs: FileSystemManager(documentsURL: root.deletingLastPathComponent()))
        async let a = first.save(draft, creating: true, projectName: "项目", tagNames: ["标签"])
        async let b = second.save(draft, creating: true, projectName: "项目", tagNames: ["标签"])
        let (savedA, savedB) = try await (a, b)
        XCTAssertEqual(savedA.todo, savedB.todo)
        let tasks = try await TodoRepository(fs: fs).listAll()
        XCTAssertEqual(tasks.count, 1)
        XCTAssertEqual(tasks.first?.version, draft.version + 1)
    }

    func testExistingMetadataIsReusedIncludingItsAppearance() async throws {
        let (fs, _) = try await filesystem()
        let project = try await ProjectRepository(fs: fs).create(Project(name: "已有项目", emoji: "📚", colorHex: "#123456"))
        let tag = try await TagRepository(fs: fs).create(TagItem(name: "已有标签", colorHex: "#654321"))
        let saved = try await DraftRepository(fs: fs).save(TodoItem(title: "复用"), creating: true, projectName: project.name, tagNames: [tag.name])
        XCTAssertEqual(saved.todo.projectId, project.id)
        XCTAssertEqual(saved.todo.tagIds, [tag.id])
        XCTAssertEqual(saved.projects, [project])
        XCTAssertEqual(saved.tags, [tag])
    }

    func testRenamingParsedMetadataDoesNotPreventRecreatingOriginalName() async throws {
        let (fs, _) = try await filesystem()
        let repo = DraftRepository(fs: fs)
        let first = try await repo.save(TodoItem(title: "第一次"), creating: true, projectName: "原项目", tagNames: ["原标签"])
        let originalProject = try XCTUnwrap(first.projects.first)
        let originalTag = try XCTUnwrap(first.tags.first)
        var renamedProject = originalProject
        renamedProject.name = "已改名项目"
        _ = try await ProjectRepository(fs: fs).save(renamedProject, replacing: originalProject)
        var renamedTag = originalTag
        renamedTag.name = "已改名标签"
        _ = try await TagRepository(fs: fs).save(renamedTag, replacing: originalTag)
        let second = try await repo.save(TodoItem(title: "第二次"), creating: true, projectName: "原项目", tagNames: ["原标签"])
        XCTAssertNotEqual(second.todo.projectId, first.todo.projectId)
        XCTAssertNotEqual(second.todo.tagIds, first.todo.tagIds)
        XCTAssertEqual(second.projects.first?.name, "原项目")
        XCTAssertEqual(second.tags.first?.name, "原标签")
    }

    func testCreationRetryCannotOverwriteLaterEditOrCreateExtraMetadata() async throws {
        let (fs, _) = try await filesystem()
        let draft = TodoItem(title: "原草稿")
        let repo = DraftRepository(fs: fs)
        let first = try await repo.save(draft, creating: true, projectName: nil, tagNames: [])
        var edited = first.todo
        edited.title = "后续修改"
        _ = try await TodoRepository(fs: fs).save(edited)
        do {
            _ = try await repo.save(draft, creating: true, projectName: "不能创建", tagNames: [])
            XCTFail("retry must not overwrite a later edit")
        } catch FileSystemError.conflictDetected { }
        let current = try await TodoRepository(fs: fs).read(id: draft.id)
        XCTAssertEqual(current.title, "后续修改")
        let projects = try await ProjectRepository(fs: fs).listAll()
        XCTAssertTrue(projects.isEmpty)
    }
}
