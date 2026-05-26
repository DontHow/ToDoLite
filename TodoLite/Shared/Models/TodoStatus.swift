import Foundation

enum TodoStatus: String, Codable, CaseIterable, Sendable {
    case inbox
    case next
    case doing
    case waiting
    case blocked
    case someday
    case done
    case cancelled
    case archived

    var displayName: String {
        switch self {
        case .inbox: return "收件箱"
        case .next: return "下一步"
        case .doing: return "进行中"
        case .waiting: return "等待中"
        case .blocked: return "已阻塞"
        case .someday: return "将来"
        case .done: return "已完成"
        case .cancelled: return "已取消"
        case .archived: return "已归档"
        }
    }
}
