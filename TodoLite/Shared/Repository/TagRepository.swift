import Foundation

actor TagRepository {
    static let shared = TagRepository()

    private let fs: FileSystemManager

    init(fs: FileSystemManager = .shared) {
        self.fs = fs
    }

    func create(_ item: TagItem) async throws -> TagItem {
        try await persist(item, replacing: nil)
    }

    func save(_ item: TagItem, replacing original: TagItem) async throws -> TagItem {
        try await persist(item, replacing: original)
    }

    private func persist(_ item: TagItem, replacing original: TagItem?) async throws -> TagItem {
        let filename = filename(for: item.id)
        do {
            return try await fs.update(TagItem.self, filename: filename, directory: .tags) { existing in
                if let original {
                    guard let existing else { throw FileSystemError.fileNotFound(filename) }
                    guard original.id == item.id, existing == original else { throw FileSystemError.conflictDetected }
                } else {
                    guard existing == nil else { throw FileSystemError.conflictDetected }
                }
                return item
            }
        } catch FileSystemError.conflictDetected {
            try await fs.writeConflictBackup(filename: filename, data: JSONEncoder().encode(item))
            throw FileSystemError.conflictDetected
        }
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
            tags.append(try await fs.read(TagItem.self, filename: file, directory: .tags))
        }
        return tags
    }

    private func filename(for id: String) -> String {
        "tag_\(id).json"
    }
}
