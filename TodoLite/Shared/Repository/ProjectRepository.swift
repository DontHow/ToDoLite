import Foundation

actor ProjectRepository {
    static let shared = ProjectRepository()

    private let fs = FileSystemManager.shared

    func save(_ project: Project) async throws -> Project {
        let filename = filename(for: project.id)
        var updated = project
        updated.updatedAt = Date()
        try await fs.write(updated, filename: filename, directory: .projects)
        return updated
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
            if let project = try? await fs.read(Project.self, filename: file, directory: .projects) {
                projects.append(project)
            }
        }
        return projects
    }

    private func filename(for id: String) -> String {
        "project_\(id).json"
    }
}
