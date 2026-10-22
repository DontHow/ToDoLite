import Foundation
import Observation

@MainActor
@Observable
final class TodoStore {
    static let shared = TodoStore()

    var todos: [TodoItem] = []
    var projects: [Project] = []
    var tags: [TagItem] = []
    var llmConfig: LLMConfig = LLMConfig()
    var focusSet: FocusSet = FocusSet()
    var showingCreateTodo = false
    var followsSystemFont: Bool = UserDefaults.standard.object(forKey: "followsSystemFont") == nil
        ? UserDefaults.standard.integer(forKey: "fontSizeLevel") == 0
        : UserDefaults.standard.bool(forKey: "followsSystemFont") {
        didSet { UserDefaults.standard.set(followsSystemFont, forKey: "followsSystemFont") }
    }
    var fontSizeLevel: Int = UserDefaults.standard.integer(forKey: "fontSizeLevel") {
        didSet {
            UserDefaults.standard.set(fontSizeLevel, forKey: "fontSizeLevel")
        }
    }

    var focusTodos: [TodoItem] {
        let ids = Set(focusSet.taskIds)
        return todos
            .filter { ids.contains($0.id) && $0.status != .done && $0.status != .archived }
    }

    var suggestedTodos: [TodoItem] {
        let ids = Set(focusSet.taskIds)
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let todayEnd = calendar.date(byAdding: .day, value: 1, to: todayStart)!
        return todos
            .filter {
                $0.status != .done && $0.status != .archived &&
                !ids.contains($0.id) &&
                ($0.dueAt.map { $0 >= todayStart && $0 < todayEnd } ?? false)
            }
    }

    var overdueTodos: [TodoItem] {
        let ids = Set(focusSet.taskIds)
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        return todos
            .filter {
                $0.status != .done && $0.status != .archived &&
                !ids.contains($0.id) &&
                ($0.dueAt.map { $0 < todayStart } ?? false)
            }
    }

    var upcomingTodos: [TodoItem] {
        let ids = Set(focusSet.taskIds)
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let tomorrowStart = calendar.date(byAdding: .day, value: 1, to: todayStart)!
        return todos
            .filter {
                $0.status != .done && $0.status != .archived &&
                !ids.contains($0.id) &&
                ($0.dueAt.map { $0 >= tomorrowStart } ?? false)
            }
            .sorted {
                let d0 = $0.dueAt ?? .distantFuture
                let d1 = $1.dueAt ?? .distantFuture
                return d0 < d1
            }
    }

    var inboxTodos: [TodoItem] {
        todos.filter { $0.status == .inbox }
    }

    var activeTodos: [TodoItem] {
        todos.filter { ![.done, .archived].contains($0.status) }
    }

    enum LoadState: Equatable {
        case idle, loading, loaded, failed(String)
    }

    private(set) var loadState: LoadState = .idle
    var operationError: String?
    private(set) var searchIndexRevision = 0

    private var refreshSequence = 0
    private var refreshTickets: [String: Int] = [:]
    private var focusMutationRevision = 0
    private let fs: FileSystemManager
    private let todoRepo: TodoRepository
    private let projectRepo: ProjectRepository
    private let tagRepo: TagRepository
    private let llmConfigRepo: LLMConfigRepository
    private let focusRepo: FocusRepository
    private let indexer = SearchIndexer.shared

    init(fs: FileSystemManager = .shared, keyStorage: any APIKeyStorage = KeychainAPIKeyStorage()) {
        self.fs = fs
        todoRepo = TodoRepository(fs: fs)
        projectRepo = ProjectRepository(fs: fs)
        tagRepo = TagRepository(fs: fs)
        llmConfigRepo = LLMConfigRepository(fs: fs, keyStorage: keyStorage)
        focusRepo = FocusRepository(fs: fs)
    }

    // MARK: - Load

    func initialize() async {
        guard loadState != .loading && loadState != .loaded else { return }
        loadState = .loading
        do {
            try await llmConfigRepo.migrateLocalFallbackKeyIfNeeded()
            let migration = try await fs.setupDirectories()
            try await loadAll()
            loadState = .loaded
            if migration.conflictFiles > 0 {
                operationError = "已合并本地数据，有 \(migration.conflictFiles) 份同名内容保存在 conflicts 冲突备份中。云端原文件已保留。"
            }
        } catch {
            loadState = .failed(error.localizedDescription)
        }
    }

    func loadAll() async throws {
        for attempt in 0..<3 {
            let revision = refreshSequence
            async let t = todoRepo.listAll()
            async let p = projectRepo.listAll()
            async let g = tagRepo.listAll()
            async let c = llmConfigRepo.loadOrDefault()
            async let f = focusRepo.load()

            // 所有数据读取成功后再发布快照，失败时保留原有内存状态。
            let snapshot = try await (t, p, g, c, f)
            guard revision == refreshSequence else {
                if attempt == 2 { throw StoreRefreshError.changed }
                continue
            }
            refreshSequence += 1
            refreshTickets.removeAll()
            focusMutationRevision += 1
            todos = snapshot.0
            projects = snapshot.1
            tags = snapshot.2
            llmConfig = snapshot.3
            focusSet = snapshot.4

            await indexer.rebuild(todos: todos, projects: projects, tags: tags)
            searchIndexRevision += 1
            WidgetDataStore.sync(todos: todos, focusSet: focusSet)
            return
        }
    }

    // MARK: - Todo CRUD

    func createTodo(title: String, description: String = "", status: TodoStatus = .inbox, projectId: String? = nil, tagIds: [String] = [], scheduledAt: Date? = nil, dueAt: Date? = nil) async throws {
        let todo = TodoItem(title: title, description: description, status: status, projectId: projectId, tagIds: tagIds, scheduledAt: scheduledAt, dueAt: dueAt)
        _ = try await todoRepo.create(todo)
        await refreshRecordFromDisk(id: todo.id, directory: "tasks")
    }

    func createTodoWithParsed(title: String, description: String = "", status: TodoStatus = .inbox, projectName: String? = nil, tagNames: [String] = [], scheduledAt: Date? = nil, dueAt: Date? = nil) async throws {
        _ = try await saveDraft(TodoItem(title: title, description: description, status: status,
                                        scheduledAt: scheduledAt, dueAt: dueAt), creating: true,
                                projectName: projectName, tagNames: tagNames)
    }

    @discardableResult
    func saveDraft(_ draft: TodoItem, creating: Bool, projectName: String? = nil, tagNames: [String] = []) async throws -> TodoItem {
        let result: DraftSaveResult
        do {
            result = try await DraftRepository(fs: fs).save(draft, creating: creating, projectName: projectName, tagNames: tagNames)
        } catch let error as DraftSaveError {
            for project in error.projects { await refreshRecordFromDisk(id: project.id, directory: "projects") }
            for tag in error.tags { await refreshRecordFromDisk(id: tag.id, directory: "tags") }
            throw error
        }
        for project in result.projects { await refreshRecordFromDisk(id: project.id, directory: "projects") }
        for tag in result.tags { await refreshRecordFromDisk(id: tag.id, directory: "tags") }
        await refreshRecordFromDisk(id: result.todo.id, directory: "tasks")
        return result.todo
    }

    func updateTodo(_ todo: TodoItem) async throws {
        _ = try await todoRepo.save(todo)
        await refreshRecordFromDisk(id: todo.id, directory: "tasks")
    }

    func deleteTodo(id: String) async throws {
        try await todoRepo.delete(id: id)
        await refreshRecordFromDisk(id: id, directory: "tasks")
    }

    // MARK: - Recovery

    func deletedTodos() async throws -> [DeletedTodo] {
        try await RecoveryRepository(fs: fs).listTrash()
    }

    func restoreTodo(_ entry: DeletedTodo) async throws {
        do {
            try await RecoveryRepository(fs: fs).restore(entry)
        } catch {
            // 任务已恢复但清理回收站失败时，仍刷新实际磁盘状态。
            try? await loadAll()
            throw error
        }
        try await loadAll()
    }

    func conflictRecords() async throws -> [ConflictRecord] {
        try await ConflictRepository(fs: fs).listAll()
    }

    func restoreConflictAsCopy(_ reviewed: ConflictRecord) async throws {
        let copy = try await ConflictRepository(fs: fs).restoreAsCopy(reviewed)
        await refreshRecordFromDisk(id: copy.id, directory: copy.directory)
    }

    func exportBackup() async throws -> Data {
        try await RecoveryRepository(fs: fs).exportData()
    }

    func importBackup(from url: URL) async throws -> RecoveryReport {
        let data = try await RecoveryRepository(fs: fs).readBackupFile(at: url)
        return try await importBackup(data)
    }

    func importBackup(_ data: Data) async throws -> RecoveryReport {
        do {
            let report = try await RecoveryRepository(fs: fs).importData(data)
            try await loadAll()
            return report
        } catch {
            try? await loadAll()
            throw error
        }
    }

    func toggleComplete(id: String) async throws {
        guard let idx = todos.firstIndex(where: { $0.id == id }) else { return }
        let todo = todos[idx]
        try await updateTodo(todo.changingStatus(to: todo.status == .done ? .doing : .done))
    }

    func changeStatus(id: String, to status: TodoStatus) async throws {
        guard let todo = todos.first(where: { $0.id == id }) else { return }
        try await updateTodo(todo.changingStatus(to: status))
    }

    func archiveTodo(id: String) async throws {
        guard let idx = todos.firstIndex(where: { $0.id == id }) else { return }
        try await updateTodo(todos[idx].archived())
    }

    // MARK: - Focus

    func addToFocus(id: String) async throws {
        try await mutateFocus(id: id, focused: true)
    }

    func removeFromFocus(id: String) async throws {
        try await mutateFocus(id: id, focused: false)
    }

    private func mutateFocus(id: String, focused: Bool) async throws {
        focusMutationRevision += 1
        let revision = focusMutationRevision
        do {
            _ = try await focusRepo.setFocused(focused, id: id)
            let current = try await focusRepo.load()
            guard revision == focusMutationRevision else { return }
            refreshSequence += 1
            focusSet = current
            WidgetDataStore.sync(todos: todos, focusSet: focusSet)
        } catch {
            // 另一个并发操作可能已经成功，失败时重新读取而非回滚旧内存快照。
            if let current = try? await focusRepo.load(), revision == focusMutationRevision {
                refreshSequence += 1
                focusSet = current
                WidgetDataStore.sync(todos: todos, focusSet: focusSet)
            }
            throw error
        }
    }

    func refreshFocusIfNeeded() async {
        let today = FocusSet.todayString()
        guard focusSet.date != today else { return }
        focusMutationRevision += 1
        let revision = focusMutationRevision
        do {
            let current = try await focusRepo.load()
            guard revision == focusMutationRevision else { return }
            refreshSequence += 1
            focusSet = current
            WidgetDataStore.sync(todos: todos, focusSet: focusSet)
        } catch {
            operationError = error.localizedDescription
        }
    }

    // MARK: - Project CRUD

    func createProject(name: String, emoji: String = "📁", colorHex: String = "#007AFF") async throws {
        let project = Project(name: name, emoji: emoji, colorHex: colorHex)
        _ = try await projectRepo.create(project)
        await refreshRecordFromDisk(id: project.id, directory: "projects")
    }

    func updateProject(_ project: Project, replacing original: Project) async throws {
        _ = try await projectRepo.save(project, replacing: original)
        await refreshRecordFromDisk(id: project.id, directory: "projects")
    }

    func deleteProject(id: String) async throws {
        try await projectRepo.delete(id: id)
        await refreshRecordFromDisk(id: id, directory: "projects")
    }

    // MARK: - Tag CRUD

    func createTag(name: String, colorHex: String = "#FF9500") async throws {
        let tag = TagItem(name: name, colorHex: colorHex)
        _ = try await tagRepo.create(tag)
        await refreshRecordFromDisk(id: tag.id, directory: "tags")
    }

    func updateTag(_ tag: TagItem, replacing original: TagItem) async throws {
        _ = try await tagRepo.save(tag, replacing: original)
        await refreshRecordFromDisk(id: tag.id, directory: "tags")
    }

    func deleteTag(id: String) async throws {
        try await tagRepo.delete(id: id)
        await refreshRecordFromDisk(id: id, directory: "tags")
    }

    // MARK: - External Sync

    private func beginRefresh(id: String, directory: String) -> Int {
        refreshSequence += 1
        refreshTickets[directory + "/" + id] = refreshSequence
        return refreshSequence
    }

    private func isCurrentRefresh(_ ticket: Int, id: String, directory: String) -> Bool {
        refreshTickets[directory + "/" + id] == ticket
    }

    /// 本地写入与云端通知共用入口；只发布最新读取请求的磁盘结果。
    func refreshRecordFromDisk(id: String, directory: String) async {
        let ticket = beginRefresh(id: id, directory: directory)
        do {
            switch directory {
            case "tasks":
                let item = try await todoRepo.read(id: id)
                guard isCurrentRefresh(ticket, id: id, directory: directory) else { return }
                await applyExternalTodo(item, refreshTicket: ticket)
            case "projects":
                let item = try await projectRepo.read(id: id)
                guard isCurrentRefresh(ticket, id: id, directory: directory) else { return }
                await applyExternalProject(item)
            case "tags":
                let item = try await tagRepo.read(id: id)
                guard isCurrentRefresh(ticket, id: id, directory: directory) else { return }
                await applyExternalTag(item)
            default: return
            }
        } catch FileSystemError.fileNotFound {
            guard isCurrentRefresh(ticket, id: id, directory: directory) else { return }
            switch directory {
            case "tasks": await removeExternalTodo(id: id)
            case "projects": await removeExternalProject(id: id)
            case "tags": await removeExternalTag(id: id)
            default: break
            }
        } catch {
            guard isCurrentRefresh(ticket, id: id, directory: directory) else { return }
            operationError = "磁盘数据刷新失败，请稍后重试：" + error.localizedDescription
        }
    }

    func applyExternalTodo(_ todo: TodoItem, refreshTicket: Int? = nil) async {
        let ticket = refreshTicket ?? beginRefresh(id: todo.id, directory: "tasks")
        if let idx = todos.firstIndex(where: { $0.id == todo.id }) {
            let local = todos[idx]
            guard local.version <= todo.version else { return }
            if local.version == todo.version {
                guard local != todo else { return }
                do {
                    try await todoRepo.backupConflict(local)
                } catch {
                    operationError = "同步冲突备份失败：" + error.localizedDescription
                    return
                }
                // 备份期间可能有其他编辑或同步，不能用旧事件覆盖最新内存状态。
                guard isCurrentRefresh(ticket, id: todo.id, directory: "tasks"),
                      let current = todos.firstIndex(where: { $0.id == todo.id }), todos[current] == local else { return }
                todos[current] = todo
                operationError = "检测到同版本任务内容冲突，已备份本机内容到 conflicts，并加载当前磁盘版本。"
            } else {
                todos[idx] = todo
            }
        } else {
            todos.append(todo)
        }
        await indexer.index(todo: todo, projects: projects, tags: tags)
        searchIndexRevision += 1
        WidgetDataStore.sync(todos: todos, focusSet: focusSet)
    }

    func removeExternalTodo(id: String) async {
        _ = beginRefresh(id: id, directory: "tasks")
        todos.removeAll { $0.id == id }
        await indexer.remove(todoId: id)
        searchIndexRevision += 1
        WidgetDataStore.sync(todos: todos, focusSet: focusSet)
    }

    func applyExternalProject(_ project: Project) async {
        _ = beginRefresh(id: project.id, directory: "projects")
        if let idx = projects.firstIndex(where: { $0.id == project.id }) {
            guard project.updatedAt > projects[idx].updatedAt else { return }
            projects[idx] = project
        } else {
            projects.append(project)
        }
        await indexer.rebuild(todos: todos, projects: projects, tags: tags)
        searchIndexRevision += 1
    }

    func removeExternalProject(id: String) async {
        _ = beginRefresh(id: id, directory: "projects")
        projects.removeAll { $0.id == id }
        await indexer.rebuild(todos: todos, projects: projects, tags: tags)
        searchIndexRevision += 1
    }

    func applyExternalTag(_ tag: TagItem) async {
        _ = beginRefresh(id: tag.id, directory: "tags")
        if let idx = tags.firstIndex(where: { $0.id == tag.id }) {
            tags[idx] = tag
        } else {
            tags.append(tag)
        }
        await indexer.rebuild(todos: todos, projects: projects, tags: tags)
        searchIndexRevision += 1
    }

    func removeExternalTag(id: String) async {
        _ = beginRefresh(id: id, directory: "tags")
        tags.removeAll { $0.id == id }
        await indexer.rebuild(todos: todos, projects: projects, tags: tags)
        searchIndexRevision += 1
    }

    func applyExternalFocus(_ newFocusSet: FocusSet) {
        guard newFocusSet.date == FocusSet.todayString() else { return }
        refreshSequence += 1
        focusSet = newFocusSet
        WidgetDataStore.sync(todos: todos, focusSet: focusSet)
    }

    // MARK: - LLM Config

    func reloadLLMConfig() async throws {
        let current = try await llmConfigRepo.loadOrDefault()
        refreshSequence += 1
        llmConfig = current
    }

    func saveLLMConfig(_ config: LLMConfig) async throws {
        try await llmConfigRepo.save(config)
        refreshSequence += 1
        llmConfig = config
    }
}

private enum StoreRefreshError: LocalizedError {
    case changed
    var errorDescription: String? { "加载期间数据发生变化，请稍后重新加载。" }
}
