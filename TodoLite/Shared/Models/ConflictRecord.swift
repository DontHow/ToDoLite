import Foundation

struct ConflictRecord: Codable, Identifiable, Equatable, Sendable {
    var filename: String
    var payload: ConflictPayload
    var id: String { filename }

    func validate() throws {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-.: ")
        guard !filename.isEmpty, filename.utf8.count <= 255,
              filename.unicodeScalars.allSatisfy({ allowed.contains($0) }),
              filename.hasPrefix(payload.filePrefix + payload.sourceID + "_conflict_"),
              filename.hasSuffix(".json") else { throw RecoveryError.invalidBackup }
        switch payload {
        case .todo(let item):
            try TodoBackup(todos: [item], projects: [], tags: [], focusSets: [], deletedTodos: []).validate()
        case .project(let item):
            try TodoBackup(todos: [], projects: [item], tags: [], focusSets: [], deletedTodos: []).validate()
        case .tag(let item):
            try TodoBackup(todos: [], projects: [], tags: [item], focusSets: [], deletedTodos: []).validate()
        }
    }

    static func supports(_ filename: String) -> Bool {
        filename.contains("_conflict_") && filename.hasSuffix(".json") &&
        ["task_", "project_", "tag_"].contains(where: { filename.hasPrefix($0) })
    }

    static func decode(filename: String, data: Data) throws -> ConflictRecord {
        let decoder = JSONDecoder()
        let payload: ConflictPayload
        if filename.hasPrefix("task_") { payload = .todo(try decoder.decode(TodoItem.self, from: data)) }
        else if filename.hasPrefix("project_") { payload = .project(try decoder.decode(Project.self, from: data)) }
        else if filename.hasPrefix("tag_") { payload = .tag(try decoder.decode(TagItem.self, from: data)) }
        else { throw RecoveryError.invalidBackup }
        let result = ConflictRecord(filename: filename, payload: payload)
        try result.validate()
        return result
    }
}

enum ConflictPayload: Codable, Equatable, Sendable {
    case todo(TodoItem)
    case project(Project)
    case tag(TagItem)

    var sourceID: String {
        switch self {
        case .todo(let item): return item.id
        case .project(let item): return item.id
        case .tag(let item): return item.id
        }
    }
    var title: String {
        switch self {
        case .todo(let item): return item.title
        case .project(let item): return item.name
        case .tag(let item): return item.name
        }
    }
    var kind: String {
        switch self { case .todo: return "任务"; case .project: return "项目"; case .tag: return "标签" }
    }
    var filePrefix: String {
        switch self { case .todo: return "task_"; case .project: return "project_"; case .tag: return "tag_" }
    }
}
