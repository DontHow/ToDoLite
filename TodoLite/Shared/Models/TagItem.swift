import Foundation

struct TagItem: Codable, Identifiable, Hashable, Sendable {
    var id: String

    var name: String
    var colorHex: String

    init(
        id: String = UUID().uuidString,
        name: String,
        colorHex: String = "#FF9500"
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
    }
}
