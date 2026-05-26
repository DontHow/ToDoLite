import Foundation

actor TagRepository {
    static let shared = TagRepository()

    private let fs = FileSystemManager.shared

    func save(_ tag: TagItem) async throws {
        let filename = filename(for: tag.id)
        try await fs.write(tag, filename: filename, directory: .tags)
    }

    func read(id: String) async throws -> TagItem {
        let filename = filename(for: id)
        return try await fs.read(TagItem.self, filename: filename, directory: .tags)
    }

    func delete(id: String) async throws {
        let filename = filename(for: id)
        try await fs.delete(filename: filename, directory: .tags)
    }

    func listAll() async throws -> [TagItem] {
        let files = try await fs.listFiles(in: .tags)
        var tags: [TagItem] = []
        for file in files where file.hasSuffix(".json") {
            if let tag = try? await fs.read(TagItem.self, filename: file, directory: .tags) {
                tags.append(tag)
            }
        }
        return tags
    }

    private func filename(for id: String) -> String {
        "tag_\(id).json"
    }
}
