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

    private let todoRepo = TodoRepository.shared
    private let projectRepo = ProjectRepository.shared
    private let tagRepo = TagRepository.shared
    private let llmConfigRepo = LLMConfigRepository.shared
    private let focusRepo = FocusRepository.shared
    private let indexer = SearchIndexer.shared

    init() {}

    // MARK: - Load

    func loadAll() async throws {
        async let t = todoRepo.listAll()
        async let p = projectRepo.listAll()
        async let g = tagRepo.listAll()

        todos = try await t
        projects = try await p
        tags = try await g
        llmConfig = await llmConfigRepo.loadOrDefault()
        focusSet = await focusRepo.load()

        await indexer.rebuild(todos: todos, projects: projects, tags: tags)
        WidgetDataStore.sync(todos: todos, focusSet: focusSet)
    }

    // MARK: - Todo CRUD

    func createTodo(title: String, description: String = "", status: TodoStatus = .inbox, projectId: String? = nil, tagIds: [String] = [], scheduledAt: Date? = nil, dueAt: Date? = nil) async throws {
        let todo = TodoItem(title: title, description: description, status: status, projectId: projectId, tagIds: tagIds, scheduledAt: scheduledAt, dueAt: dueAt)
        let saved = try await todoRepo.save(todo)
        todos.append(saved)
        await indexer.index(todo: saved, projects: projects, tags: tags)
        WidgetDataStore.sync(todos: todos, focusSet: focusSet)
    }

    func createTodoWithParsed(title: String, description: String = "", status: TodoStatus = .inbox, projectName: String? = nil, tagNames: [String] = [], scheduledAt: Date? = nil, dueAt: Date? = nil) async throws {
        var projectId: String?
        if let name = projectName {
            if let existing = projects.first(where: { $0.name == name }) {
                projectId = existing.id
            } else {
                let newProject = Project(name: name)
                try await projectRepo.save(newProject)
                projects.append(newProject)
                projectId = newProject.id
            }
        }

        var tagIds: [String] = []
        for name in tagNames {
            if let existing = tags.first(where: { $0.name == name }) {
                tagIds.append(existing.id)
            } else {
                let newTag = TagItem(name: name)
                try await tagRepo.save(newTag)
                tags.append(newTag)
                tagIds.append(newTag.id)
            }
        }

        try await createTodo(
            title: title,
            description: description,
            status: status,
            projectId: projectId,
            tagIds: tagIds,
            scheduledAt: scheduledAt,
            dueAt: dueAt
        )
    }

    func updateTodo(_ todo: TodoItem) async throws {
        let saved = try await todoRepo.save(todo)
        if let idx = todos.firstIndex(where: { $0.id == saved.id }) {
            todos[idx] = saved
        }
        await indexer.index(todo: saved, projects: projects, tags: tags)
        WidgetDataStore.sync(todos: todos, focusSet: focusSet)
    }

    func deleteTodo(id: String) async throws {
        try await todoRepo.delete(id: id)
        todos.removeAll { $0.id == id }
        await indexer.remove(todoId: id)
        WidgetDataStore.sync(todos: todos, focusSet: focusSet)
    }

    func toggleComplete(id: String) async throws {
        guard let idx = todos.firstIndex(where: { $0.id == id }) else { return }
        var todo = todos[idx]
        if todo.status == .done {
            todo.status = .doing
            todo.completedAt = nil
        } else {
            todo.status = .done
            todo.completedAt = Date()
        }
        try await updateTodo(todo)
    }

    func archiveTodo(id: String) async throws {
        guard let idx = todos.firstIndex(where: { $0.id == id }) else { return }
        var todo = todos[idx]
        todo.status = .archived
        todo.completedAt = Date()
        try await updateTodo(todo)
    }

    // MARK: - Focus

    func addToFocus(id: String) async throws {
        guard !focusSet.taskIds.contains(id) else { return }
        let previous = focusSet
        focusSet.taskIds.append(id)
        do {
            try await focusRepo.save(focusSet)
            WidgetDataStore.sync(todos: todos, focusSet: focusSet)
        } catch {
            focusSet = previous
            throw error
        }
    }

    func removeFromFocus(id: String) async throws {
        let previous = focusSet
        focusSet.taskIds.removeAll { $0 == id }
        do {
            try await focusRepo.save(focusSet)
            WidgetDataStore.sync(todos: todos, focusSet: focusSet)
        } catch {
            focusSet = previous
            throw error
        }
    }

    func refreshFocusIfNeeded() async {
        let today = FocusSet.todayString()
        guard focusSet.date != today else { return }
        focusSet = await focusRepo.load()
        WidgetDataStore.sync(todos: todos, focusSet: focusSet)
    }

    // MARK: - Project CRUD

    func createProject(name: String, emoji: String = "📁", colorHex: String = "#007AFF") async throws {
        let project = Project(name: name, emoji: emoji, colorHex: colorHex)
        try await projectRepo.save(project)
        projects.append(project)
    }

    func updateProject(_ project: Project) async throws {
        try await projectRepo.save(project)
        if let idx = projects.firstIndex(where: { $0.id == project.id }) {
            projects[idx] = project
        }
        await indexer.rebuild(todos: todos, projects: projects, tags: tags)
    }

    func deleteProject(id: String) async throws {
        try await projectRepo.delete(id: id)
        projects.removeAll { $0.id == id }
        await indexer.rebuild(todos: todos, projects: projects, tags: tags)
    }

    // MARK: - Tag CRUD

    func createTag(name: String, colorHex: String = "#FF9500") async throws {
        let tag = TagItem(name: name, colorHex: colorHex)
        try await tagRepo.save(tag)
        tags.append(tag)
    }

    func updateTag(_ tag: TagItem) async throws {
        try await tagRepo.save(tag)
        if let idx = tags.firstIndex(where: { $0.id == tag.id }) {
            tags[idx] = tag
        }
        await indexer.rebuild(todos: todos, projects: projects, tags: tags)
    }

    func deleteTag(id: String) async throws {
        try await tagRepo.delete(id: id)
        tags.removeAll { $0.id == id }
        await indexer.rebuild(todos: todos, projects: projects, tags: tags)
    }

    // MARK: - External Sync

    func applyExternalTodo(_ todo: TodoItem) async {
        if let idx = todos.firstIndex(where: { $0.id == todo.id }) {
            guard todos[idx].version < todo.version else { return }
            todos[idx] = todo
        } else {
            todos.append(todo)
        }
        await indexer.index(todo: todo, projects: projects, tags: tags)
        WidgetDataStore.sync(todos: todos, focusSet: focusSet)
    }

    func removeExternalTodo(id: String) async {
        todos.removeAll { $0.id == id }
        await indexer.remove(todoId: id)
        WidgetDataStore.sync(todos: todos, focusSet: focusSet)
    }

    func applyExternalProject(_ project: Project) async {
        if let idx = projects.firstIndex(where: { $0.id == project.id }) {
            projects[idx] = project
        } else {
            projects.append(project)
        }
        await indexer.rebuild(todos: todos, projects: projects, tags: tags)
    }

    func removeExternalProject(id: String) async {
        projects.removeAll { $0.id == id }
        await indexer.rebuild(todos: todos, projects: projects, tags: tags)
    }

    func applyExternalTag(_ tag: TagItem) async {
        if let idx = tags.firstIndex(where: { $0.id == tag.id }) {
            tags[idx] = tag
        } else {
            tags.append(tag)
        }
        await indexer.rebuild(todos: todos, projects: projects, tags: tags)
    }

    func removeExternalTag(id: String) async {
        tags.removeAll { $0.id == id }
        await indexer.rebuild(todos: todos, projects: projects, tags: tags)
    }

    func applyExternalFocus(_ newFocusSet: FocusSet) {
        guard newFocusSet.date == FocusSet.todayString() else { return }
        focusSet = newFocusSet
        WidgetDataStore.sync(todos: todos, focusSet: focusSet)
    }

    // MARK: - LLM Config

    func saveLLMConfig(_ config: LLMConfig) async throws {
        try await llmConfigRepo.save(config)
        llmConfig = config
    }
}
