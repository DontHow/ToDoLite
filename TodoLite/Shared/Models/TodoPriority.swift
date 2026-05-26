import Foundation

enum TodoPriority: String, Codable, CaseIterable, Sendable {
    case low
    case medium
    case high

    var sortValue: Int {
        switch self {
        case .low: return 0
        case .medium: return 1
        case .high: return 2
        }
    }

    var displayName: String {
        switch self {
        case .low: return "低"
        case .medium: return "中"
        case .high: return "高"
        }
    }
}
