import Foundation
import Observation

@Observable
final class TodoStore {
    static let shared = TodoStore()

    var todos: [TodoItem] = []
    var projects: [Project] = []
    var tags: [TagItem] = []

    var todayTodos: [TodoItem] {
        todos.filter { TodoStore.isToday($0) }.sorted {
            if $0.isPinnedToday != $1.isPinnedToday {
                return $0.isPinnedToday
            }
            if $0.priority.sortValue != $1.priority.sortValue {
                return $0.priority.sortValue > $1.priority.sortValue
            }
            return $0.createdAt < $1.createdAt
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

        await indexer.rebuild(todos: todos, projects: projects, tags: tags)
    }

    // MARK: - Todo CRUD

    func createTodo(title: String, description: String = "", status: TodoStatus = .inbox, priority: TodoPriority = .medium, projectId: String? = nil, tagIds: [String] = [], scheduledAt: Date? = nil, dueAt: Date? = nil) async throws {
        let todo = TodoItem(title: title, description: description, status: status, priority: priority, projectId: projectId, tagIds: tagIds, scheduledAt: scheduledAt, dueAt: dueAt)
        try await todoRepo.save(todo)
        todos.append(todo)
        await indexer.index(todo: todo, projects: projects, tags: tags)
    }

    func updateTodo(_ todo: TodoItem) async throws {
        try await todoRepo.save(todo)
        if let idx = todos.firstIndex(where: { $0.id == todo.id }) {
            todos[idx] = todo
        }
        await indexer.index(todo: todo, projects: projects, tags: tags)
    }

    func deleteTodo(id: String) async throws {
        try await todoRepo.delete(id: id)
        todos.removeAll { $0.id == id }
        await indexer.remove(todoId: id)
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

    func pinToToday(id: String) async throws {
        guard let idx = todos.firstIndex(where: { $0.id == id }) else { return }
        var todo = todos[idx]
        todo.isPinnedToday = true
        try await updateTodo(todo)
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
    }

    func deleteProject(id: String) async throws {
        try await projectRepo.delete(id: id)
        projects.removeAll { $0.id == id }
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
    }

    func deleteTag(id: String) async throws {
        try await tagRepo.delete(id: id)
        tags.removeAll { $0.id == id }
    }

    // MARK: - Today Logic

    static func isToday(_ todo: TodoItem, now: Date = Date()) -> Bool {
        if todo.status == .done || todo.status == .archived {
            return false
        }
        if todo.isPinnedToday {
            return true
        }
        let calendar = Calendar.current
        if let scheduled = todo.scheduledAt, calendar.isDateInToday(scheduled) {
            return true
        }
        if let due = todo.dueAt, due <= now {
            return true
        }
        return false
    }
}
