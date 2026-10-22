import Foundation

actor ProjectRepository {
    static let shared = ProjectRepository()

    private let fs: FileSystemManager

    init(fs: FileSystemManager = .shared) {
        self.fs = fs
    }

    func create(_ item: Project) async throws -> Project {
        try await persist(item, replacing: nil)
    }

    func save(_ item: Project, replacing original: Project) async throws -> Project {
        try await persist(item, replacing: original)
    }

    private func persist(_ item: Project, replacing original: Project?) async throws -> Project {
        let filename = filename(for: item.id)
        do {
            return try await fs.update(Project.self, filename: filename, directory: .projects) { existing in
                if let original {
                    guard let existing else { throw FileSystemError.fileNotFound(filename) }
                    guard original.id == item.id, existing == original else { throw FileSystemError.conflictDetected }
                } else {
                    guard existing == nil else { throw FileSystemError.conflictDetected }
                }
                var saved = item
                saved.updatedAt = Date()
                return saved
            }
        } catch FileSystemError.conflictDetected {
            try await fs.writeConflictBackup(filename: filename, data: JSONEncoder().encode(item))
            throw FileSystemError.conflictDetected
        }
    }

    func read(id: String) async throws -> Project {
        let filename = filename(for: id)
        return try await fs.read(Project.self, filename: filename, directory: .projects)
    }

    func delete(id: String) async throws {
        let filename = filename(for: id)
        try await fs.delete(filename: filename, directory: .projects)
    }

    func listAll() async throws -> [Project] {
        let files = try await fs.listFiles(in: .projects)
        var projects: [Project] = []
        for file in files where file.hasSuffix(".json") {
            projects.append(try await fs.read(Project.self, filename: file, directory: .projects))
        }
        return projects
    }

    private func filename(for id: String) -> String {
        "project_\(id).json"
    }
}
