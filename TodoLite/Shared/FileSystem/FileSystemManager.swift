import Foundation

enum FileSystemError: Error {
    case containerNotAvailable
    case directoryCreationFailed
    case readFailed
    case writeFailed
    case deleteFailed
    case encodeFailed
    case decodeFailed
    case conflictDetected
}

actor FileSystemManager {
    static let shared = FileSystemManager()

    private let appDirName = "TodoLite"
    private let tasksDirName = "tasks"
    private let projectsDirName = "projects"
    private let tagsDirName = "tags"
    private let trashDirName = "trash"
    private let archiveDirName = "archive"
    private let conflictsDirName = "conflicts"
    private let metaDirName = "meta"
    private let configDirName = "config"

    private var containerURL: URL?
    private let localDocumentsURL: URL?
    private let usesICloud: Bool

    init() {
        let localURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        localDocumentsURL = localURL
        if let url = FileManager.default.url(forUbiquityContainerIdentifier: nil) {
            containerURL = url.appendingPathComponent("Documents", isDirectory: true)
            usesICloud = true
        } else {
            containerURL = localURL
            usesICloud = false
        }
    }

    // MARK: - Directory URLs

    private func appDirectory() throws -> URL {
        guard let container = containerURL else {
            throw FileSystemError.containerNotAvailable
        }
        return container.appendingPathComponent(appDirName, isDirectory: true)
    }

    private func tasksDirectory() throws -> URL {
        try appDirectory().appendingPathComponent(tasksDirName, isDirectory: true)
    }

    private func projectsDirectory() throws -> URL {
        try appDirectory().appendingPathComponent(projectsDirName, isDirectory: true)
    }

    private func tagsDirectory() throws -> URL {
        try appDirectory().appendingPathComponent(tagsDirName, isDirectory: true)
    }

    private func trashDirectory() throws -> URL {
        try appDirectory().appendingPathComponent(trashDirName, isDirectory: true)
    }

    private func archiveDirectory() throws -> URL {
        try appDirectory().appendingPathComponent(archiveDirName, isDirectory: true)
    }

    private func conflictsDirectory() throws -> URL {
        try appDirectory().appendingPathComponent(conflictsDirName, isDirectory: true)
    }

    private func metaDirectory() throws -> URL {
        try appDirectory().appendingPathComponent(metaDirName, isDirectory: true)
    }

    private func configDirectory() throws -> URL {
        try appDirectory().appendingPathComponent(configDirName, isDirectory: true)
    }

    // MARK: - Setup

    func setupDirectories() async throws {
        let dirs = [
            try tasksDirectory(),
            try projectsDirectory(),
            try tagsDirectory(),
            try trashDirectory(),
            try archiveDirectory(),
            try conflictsDirectory(),
            try metaDirectory(),
            try configDirectory(),
        ]

        for dir in dirs {
            try await createDirectoryIfNeeded(at: dir)
        }

        try await migrateLocalFallbackDataIfNeeded()
    }

    private func createDirectoryIfNeeded(at url: URL) async throws {
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
            return
        }
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    // MARK: - Local Fallback Migration

    private func migrateLocalFallbackDataIfNeeded() async throws {
        guard usesICloud, let localDocumentsURL else { return }

        let localAppURL = localDocumentsURL.appendingPathComponent(appDirName, isDirectory: true)
        guard FileManager.default.fileExists(atPath: localAppURL.path) else { return }

        let sourceDirectoryNames = [tasksDirName, projectsDirName, tagsDirName, metaDirName, configDirName]
        let cloudHasSourceData = try sourceDirectoryNames.contains { name in
            let directory = try appDirectory().appendingPathComponent(name, isDirectory: true)
            return try !FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil).isEmpty
        }
        guard !cloudHasSourceData else { return }

        let allDirectoryNames = [
            tasksDirName, projectsDirName, tagsDirName, trashDirName,
            archiveDirName, conflictsDirName, metaDirName, configDirName,
        ]

        for name in allDirectoryNames {
            let sourceDirectory = localAppURL.appendingPathComponent(name, isDirectory: true)
            guard FileManager.default.fileExists(atPath: sourceDirectory.path) else { continue }

            let destinationDirectory = try appDirectory().appendingPathComponent(name, isDirectory: true)
            let files = try FileManager.default.contentsOfDirectory(
                at: sourceDirectory,
                includingPropertiesForKeys: [.isRegularFileKey]
            )

            for sourceURL in files {
                let values = try sourceURL.resourceValues(forKeys: [.isRegularFileKey])
                guard values.isRegularFile == true else { continue }
                let destinationURL = destinationDirectory.appendingPathComponent(sourceURL.lastPathComponent)
                guard !FileManager.default.fileExists(atPath: destinationURL.path) else { continue }
                let data = try Data(contentsOf: sourceURL)
                try await writeCoordinated(data, to: destinationURL)
            }
        }
    }

    private func writeCoordinated(_ data: Data, to fileURL: URL) async throws {
        let coordinator = NSFileCoordinator()
        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                var coordinationError: NSError?
                coordinator.coordinate(writingItemAt: fileURL, options: .forReplacing, error: &coordinationError) { url in
                    do {
                        try data.write(to: url, options: .atomic)
                        continuation.resume()
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
                if let coordinationError {
                    continuation.resume(throwing: coordinationError)
                }
            }
        } catch {
            throw FileSystemError.writeFailed
        }
    }

    // MARK: - Write

    func write<T: Encodable>(_ value: T, filename: String, directory: FileDirectory) async throws {
        let dirURL = try directoryURL(directory)
        let fileURL = dirURL.appendingPathComponent(filename)

        let data = try JSONEncoder().encode(value)

        let coordinator = NSFileCoordinator()

        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                var nsError: NSError?
                coordinator.coordinate(writingItemAt: fileURL, options: .forReplacing, error: &nsError) { url in
                    do {
                        try data.write(to: url, options: .atomic)
                    } catch {
                        continuation.resume(throwing: error)
                        return
                    }
                    continuation.resume()
                }
                if let error = nsError {
                    continuation.resume(throwing: error)
                }
            }
        } catch {
            throw FileSystemError.writeFailed
        }
    }

    // MARK: - Read

    func read<T: Decodable>(_ type: T.Type, filename: String, directory: FileDirectory) async throws -> T {
        let dirURL = try directoryURL(directory)
        let fileURL = dirURL.appendingPathComponent(filename)

        let coordinator = NSFileCoordinator()
        var resultData: Data?

        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                var nsError: NSError?
                coordinator.coordinate(readingItemAt: fileURL, options: .withoutChanges, error: &nsError) { url in
                    do {
                        resultData = try Data(contentsOf: url)
                    } catch {
                        continuation.resume(throwing: error)
                        return
                    }
                    continuation.resume()
                }
                if let error = nsError {
                    continuation.resume(throwing: error)
                }
            }
        } catch {
            throw FileSystemError.readFailed
        }

        guard let data = resultData else {
            throw FileSystemError.readFailed
        }

        return try JSONDecoder().decode(type, from: data)
    }

    // MARK: - Delete

    func delete(filename: String, directory: FileDirectory) async throws {
        let dirURL = try directoryURL(directory)
        let fileURL = dirURL.appendingPathComponent(filename)

        let coordinator = NSFileCoordinator()

        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                var nsError: NSError?
                coordinator.coordinate(writingItemAt: fileURL, options: .forDeleting, error: &nsError) { url in
                    do {
                        try FileManager.default.removeItem(at: url)
                    } catch {
                        continuation.resume(throwing: error)
                        return
                    }
                    continuation.resume()
                }
                if let error = nsError {
                    continuation.resume(throwing: error)
                }
            }
        } catch {
            throw FileSystemError.deleteFailed
        }
    }

    // MARK: - List

    func listFiles(in directory: FileDirectory) async throws -> [String] {
        let dirURL = try directoryURL(directory)

        guard FileManager.default.fileExists(atPath: dirURL.path) else {
            return []
        }

        let contents = try FileManager.default.contentsOfDirectory(at: dirURL, includingPropertiesForKeys: nil)
        return contents.map { $0.lastPathComponent }
    }

    // MARK: - Conflict Backup

    func writeConflictBackup(filename: String, data: Data) async throws {
        let dir = try conflictsDirectory()
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let name = filename.replacingOccurrences(of: ".json", with: "") + "_conflict_" + timestamp + ".json"
        let fileURL = dir.appendingPathComponent(name)
        try data.write(to: fileURL, options: .atomic)
    }

    // MARK: - Helpers

    private func directoryURL(_ directory: FileDirectory) throws -> URL {
        switch directory {
        case .tasks: return try tasksDirectory()
        case .projects: return try projectsDirectory()
        case .tags: return try tagsDirectory()
        case .trash: return try trashDirectory()
        case .archive: return try archiveDirectory()
        case .conflicts: return try conflictsDirectory()
        case .meta: return try metaDirectory()
        case .config: return try configDirectory()
        }
    }
}

enum FileDirectory {
    case tasks
    case projects
    case tags
    case trash
    case archive
    case conflicts
    case meta
    case config
}
