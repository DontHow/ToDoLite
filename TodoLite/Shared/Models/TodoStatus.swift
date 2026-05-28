import SwiftUI

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

    var color: Color {
        switch self {
        case .inbox: return Color(hex: "A8D8F0")
        case .doing: return Color(hex: "F7E8DF")
        case .waiting: return Color(hex: "E6E6F9")
        case .done: return Color(hex: "E6F9F2")
        case .archived: return Color(hex: "8E8E93")
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
