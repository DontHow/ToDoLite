import Foundation

enum TodoStatus: String, Codable, CaseIterable, Sendable {
    case inbox
    case doing
    case waiting
    case done
    case archived

    var displayName: String {
        switch self {
        case .inbox: return "收件箱"
        case .doing: return "进行中"
        case .waiting: return "等待中"
        case .done: return "已完成"
        case .archived: return "已归档"
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        switch raw {
        case "inbox": self = .inbox
        case "next", "doing": self = .doing
        case "waiting", "blocked", "someday": self = .waiting
        case "done": self = .done
        case "cancelled", "archived": self = .archived
        default: self = .inbox
        }
    }
}
