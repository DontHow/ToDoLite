import Foundation
import CryptoKit

struct DraftSaveResult: Sendable {
    var todo: TodoItem
    var projects: [Project]
    var tags: [TagItem]
}

struct DraftSaveError: LocalizedError {
    var reason: String
    var projects: [Project]
    var tags: [TagItem]
    var errorDescription: String? {
        "任务未保存：\(reason) 相关的 \(projects.count) 个项目、\(tags.count) 个标签已保留，重试时会复用。"
    }
}

actor DraftRepository {
    private let fs: FileSystemManager
    init(fs: FileSystemManager) { self.fs = fs }

    func save(_ draft: TodoItem, creating: Bool, projectName: String?, tagNames: [String]) async throws -> DraftSaveResult {
        var resolved = draft
        let todoRepo = TodoRepository(fs: fs)
        let projectRepo = ProjectRepository(fs: fs)
        let tagRepo = TagRepository(fs: fs)
        let existingProjects = projectName == nil ? [] : try await projectRepo.listAll()
        let existingTags = tagNames.isEmpty ? [] : try await tagRepo.listAll()
        var plannedProject: Project?
        if let name = projectName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            plannedProject = existingProjects.first { $0.name == name }
                ?? Project(id: Self.metadataID(name, occupied: Set(existingProjects.map(\.id))), name: name)
            resolved.projectId = plannedProject?.id
        }
        var plannedTags: [TagItem] = []
        var seenNames = Set<String>()
        for rawName in tagNames {
            let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, seenNames.insert(name).inserted else { continue }
            let tag = existingTags.first { $0.name == name }
                ?? TagItem(id: Self.metadataID(name, occupied: Set(existingTags.map(\.id))), name: name)
            plannedTags.append(tag)
            if !resolved.tagIds.contains(tag.id) { resolved.tagIds.append(tag.id) }
        }
        // 在首次写入之前验证文件名和版本范围。
        try TodoBackup(todos: [resolved], projects: [], tags: [], focusSets: [], deletedTodos: []).validate()
        try await todoRepo.validateDraft(resolved, creating: creating)
        var projects: [Project] = []
        var tags: [TagItem] = []
        var createdProjects: [Project] = []
        var createdTags: [TagItem] = []
        do {
            if let plannedProject {
                let actual = try await fs.insertOrRead(plannedProject, filename: "project_\(plannedProject.id).json", directory: .projects)
                guard actual.id == plannedProject.id, actual.name == plannedProject.name else { throw DraftMetadataError.changed }
                projects.append(actual)
                if !existingProjects.contains(where: { $0.id == actual.id }) { createdProjects.append(actual) }
            }
            for tag in plannedTags {
                let actual = try await fs.insertOrRead(tag, filename: "tag_\(tag.id).json", directory: .tags)
                guard actual.id == tag.id, actual.name == tag.name else { throw DraftMetadataError.changed }
                tags.append(actual)
                if !existingTags.contains(where: { $0.id == actual.id }) { createdTags.append(actual) }
            }
            let saved = try await (creating ? todoRepo.createRecovering(resolved) : todoRepo.save(resolved))
            return DraftSaveResult(todo: saved, projects: projects, tags: tags)
        } catch {
            // JSON 跨文件保存不是事务。保留可能已被其他任务引用的元数据，明确报告并允许重试。
            if !createdProjects.isEmpty || !createdTags.isEmpty {
                throw DraftSaveError(reason: error.localizedDescription, projects: createdProjects, tags: createdTags)
            }
            throw error
        }
    }

    private static func metadataID(_ name: String, occupied: Set<String>) -> String {
        let normalized = name.precomposedStringWithCanonicalMapping
        let digest = SHA256.hash(data: Data(normalized.utf8)).map { String(format: "%02x", $0) }.joined()
        let base = "parsed_" + digest
        var candidate = base
        var suffix = 1
        while occupied.contains(candidate) {
            candidate = "\(base)_\(suffix)"
            suffix += 1
        }
        return candidate
    }
}

private enum DraftMetadataError: LocalizedError {
    case changed
    var errorDescription: String? { "项目或标签已被其他操作修改，请重新选择后再试。" }
}
