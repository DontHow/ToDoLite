import Foundation
import SQLite3

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

actor SearchIndexer {
    static let shared = SearchIndexer()

    private var db: OpaquePointer?
    private let dbPath: URL

    deinit {
        if let db { sqlite3_close(db) }
    }

    internal init() {
        let fm = FileManager.default
        let dir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("TodoLite", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        dbPath = dir.appendingPathComponent("search_index.sqlite")
        guard sqlite3_open(dbPath.path, &db) == SQLITE_OK else { return }
        sqlite3_exec(db, "DROP TABLE IF EXISTS todo_fts;", nil, nil, nil)
        let createSQL = """
            CREATE VIRTUAL TABLE IF NOT EXISTS todo_fts USING fts5(
                todoId UNINDEXED, title, description, project, tags
            );
            """
        sqlite3_exec(db, createSQL, nil, nil, nil)
    }

    // MARK: - Index

    func index(todo: TodoItem, projects: [Project], tags: [TagItem]) {
        let projectName = projects.first { $0.id == todo.projectId }?.name ?? ""
        let tagNames = todo.tagIds.compactMap { id in tags.first { $0.id == id }?.name }.joined(separator: " ")

        let sql = """
            INSERT INTO todo_fts(todoId, title, description, project, tags)
            VALUES (?, ?, ?, ?, ?)
            """

        remove(todoId: todo.id)
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        sqlite3_bind_text(stmt, 1, todo.id, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, todo.title, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 3, todo.description, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 4, projectName, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 5, tagNames, -1, SQLITE_TRANSIENT)
        sqlite3_step(stmt)
        sqlite3_finalize(stmt)
    }

    func remove(todoId: String) {
        let sql = "DELETE FROM todo_fts WHERE todoId = ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        sqlite3_bind_text(stmt, 1, todoId, -1, SQLITE_TRANSIENT)
        sqlite3_step(stmt)
        sqlite3_finalize(stmt)
    }

    func rebuild(todos: [TodoItem], projects: [Project], tags: [TagItem]) {
        _ = exec("DELETE FROM todo_fts;")
        for todo in todos {
            index(todo: todo, projects: projects, tags: tags)
        }
    }

    // MARK: - Search

    func search(query: String) -> [String] {
        let terms = query
            .split(whereSeparator: { $0.isWhitespace })
            .map { term in
                let escaped = term.replacingOccurrences(of: "\"", with: "\"\"")
                return "\"\(escaped)\"*"
            }
        guard !terms.isEmpty else { return [] }
        let matchQuery = terms.joined(separator: " ")

        let sql = "SELECT todoId FROM todo_fts WHERE todo_fts MATCH ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        sqlite3_bind_text(stmt, 1, matchQuery, -1, SQLITE_TRANSIENT)

        var ids: [String] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let cstr = sqlite3_column_text(stmt, 0) {
                ids.append(String(cString: cstr))
            }
        }
        sqlite3_finalize(stmt)
        return ids
    }

    // MARK: - Helpers

    private func exec(_ sql: String) -> Bool {
        return sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK
    }
}
