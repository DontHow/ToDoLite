import Foundation

struct Project: Codable, Identifiable, Hashable, Sendable {
    var id: String

    var name: String

    var emoji: String
    var colorHex: String

    var isArchived: Bool

    var createdAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        name: String,
        emoji: String = "📁",
        colorHex: String = "#007AFF",
        isArchived: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.colorHex = colorHex
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
