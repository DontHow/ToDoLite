import Foundation
import SQLite3

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

enum SearchIndexError: LocalizedError {
    case unavailable

    var errorDescription: String? { "搜索索引暂时不可用，请重新打开应用后重试。" }
}

actor SearchIndexer {
    static let shared = SearchIndexer()

    private var db: OpaquePointer?
    private var needsRebuild = false

    deinit {
        if let db { sqlite3_close(db) }
    }

    init(inMemory: Bool = false) {
        let path: String
        if inMemory {
            path = ":memory:"
        } else {
            let fm = FileManager.default
            guard let support = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
            let dir = support.appendingPathComponent("TodoLite", isDirectory: true)
            do { try fm.createDirectory(at: dir, withIntermediateDirectories: true) }
            catch { return }
            path = dir.appendingPathComponent("search_index.sqlite").path
        }
        guard sqlite3_open(path, &db) == SQLITE_OK else { return }
        // 索引内容由启动时的 rebuild 更新，不在每次打开数据库时删除表。
        let createSQL = """
            CREATE VIRTUAL TABLE IF NOT EXISTS todo_fts USING fts5(
                todoId UNINDEXED, title, description, project, tags
            );
            """
        needsRebuild = sqlite3_exec(db, createSQL, nil, nil, nil) != SQLITE_OK
    }

    // MARK: - Index

    func index(todo: TodoItem, projects: [Project], tags: [TagItem]) {
        transaction {
            delete(todoId: todo.id) && insert(todo: todo, projects: Self.projectNames(projects), tags: Self.tagNames(tags))
        }
    }

    func remove(todoId: String) {
        if !delete(todoId: todoId) { needsRebuild = true }
    }

    func rebuild(todos: [TodoItem], projects: [Project], tags: [TagItem]) {
        let projectNames = Self.projectNames(projects)
        let tagNames = Self.tagNames(tags)
        if transaction({
            guard exec("DELETE FROM todo_fts;") else { return false }
            return todos.allSatisfy { insert(todo: $0, projects: projectNames, tags: tagNames) }
        }) {
            needsRebuild = false
        }
    }

    // MARK: - Search

    func search(query: String) throws -> [String] {
        guard db != nil, !needsRebuild else { throw SearchIndexError.unavailable }
        let terms = query.split(whereSeparator: { $0.isWhitespace }).map { term in
            let escaped = Self.searchableText(String(term)).replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\"*"
        }
        guard !terms.isEmpty else { return [] }

        let sql = "SELECT todoId FROM todo_fts WHERE todo_fts MATCH ? ORDER BY bm25(todo_fts), todoId;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { throw SearchIndexError.unavailable }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, terms.joined(separator: " "), -1, SQLITE_TRANSIENT)
        var ids: [String] = []
        var status = sqlite3_step(stmt)
        while status == SQLITE_ROW {
            if let cstr = sqlite3_column_text(stmt, 0) { ids.append(String(cString: cstr)) }
            status = sqlite3_step(stmt)
        }
        guard status == SQLITE_DONE else { throw SearchIndexError.unavailable }
        return ids
    }

    /// 汉字逐字索引，查询按同样方式转为连续短语，支持词中匹配和单字查询。
    /// 拉丁文本继续使用 unicode61 的分词、大小写和前缀匹配。
    private static func searchableText(_ text: String) -> String {
        var result = ""
        for scalar in text.unicodeScalars {
            if scalar.properties.isIdeographic {
                result += " \(scalar) "
            } else {
                result.unicodeScalars.append(scalar)
            }
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Helpers

    private static func projectNames(_ projects: [Project]) -> [String: String] {
        Dictionary(projects.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
    }

    private static func tagNames(_ tags: [TagItem]) -> [String: String] {
        Dictionary(tags.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
    }

    private func insert(todo: TodoItem, projects: [String: String], tags: [String: String]) -> Bool {
        let sql = "INSERT INTO todo_fts(todoId, title, description, project, tags) VALUES (?, ?, ?, ?, ?);"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return false }
        defer { sqlite3_finalize(stmt) }
        let fields = [todo.id, Self.searchableText(todo.title), Self.searchableText(todo.description),
                      Self.searchableText(todo.projectId.flatMap { projects[$0] } ?? ""),
                      Self.searchableText(todo.tagIds.compactMap { tags[$0] }.joined(separator: " "))]
        for (offset, value) in fields.enumerated() {
            sqlite3_bind_text(stmt, Int32(offset + 1), value, -1, SQLITE_TRANSIENT)
        }
        return sqlite3_step(stmt) == SQLITE_DONE
    }

    private func delete(todoId: String) -> Bool {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "DELETE FROM todo_fts WHERE todoId = ?;", -1, &stmt, nil) == SQLITE_OK else { return false }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, todoId, -1, SQLITE_TRANSIENT)
        return sqlite3_step(stmt) == SQLITE_DONE
    }

    @discardableResult
    private func transaction(_ operation: () -> Bool) -> Bool {
        guard exec("BEGIN IMMEDIATE;") else { needsRebuild = true; return false }
        if operation(), exec("COMMIT;") { return true }
        _ = exec("ROLLBACK;")
        needsRebuild = true
        return false
    }

    private func exec(_ sql: String) -> Bool {
        sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK
    }
}
