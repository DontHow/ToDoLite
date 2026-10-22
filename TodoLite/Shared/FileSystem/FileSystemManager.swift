import Foundation
import CryptoKit

enum FileSystemError: Error, Equatable {
    case fileNotFound(String)
    case invalidFile(String)
    case downloadPending(String)
    case containerNotAvailable
    case directoryCreationFailed
    case readFailed
    case writeFailed
    case deleteFailed
    case encodeFailed
    case decodeFailed
    case conflictDetected
}

extension FileSystemError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .fileNotFound(let filename): return "找不到文件：\(filename)。请重新加载后再试。"
        case .downloadPending(let filename): return "iCloud 文件尚未下载：\(filename)。已请求下载，请稍后重试。"
        case .invalidFile(let filename): return "文件无法解析：\(filename)。原文件已保留，请检查备份或修复后重试。"
        case .conflictDetected: return "数据已被其他操作修改，或存在 iCloud 冲突。请重新加载后再试；任务、项目和标签的冲突编辑会保存在 conflicts 中。"
        case .containerNotAvailable: return "数据目录不可用，请检查 iCloud 或本地存储。"
        case .directoryCreationFailed: return "无法创建数据目录。"
        case .readFailed: return "无法读取数据，请检查文件权限或 iCloud 下载状态。"
        case .writeFailed: return "无法保存数据，请检查存储空间和文件权限。"
        case .deleteFailed: return "无法删除文件，请稍后重试。"
        case .encodeFailed: return "数据编码失败，未保存更改。"
        case .decodeFailed: return "数据解析失败，原文件已保留。"
        }
    }
}

struct LocalMigrationReport {
    var copiedFiles = 0
    var conflictFiles = 0
}

private struct LocalMigrationReceipt: Codable {
    let fingerprint: String
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

    /// 独立目录用于测试和显式的本地数据源，不访问用户的 iCloud 容器。
    init(documentsURL: URL, localFallbackDocumentsURL: URL? = nil) {
        containerURL = documentsURL
        localDocumentsURL = localFallbackDocumentsURL ?? documentsURL
        usesICloud = localFallbackDocumentsURL != nil
    }

    func cloudAppDirectory() throws -> URL? {
        usesICloud ? try appDirectory() : nil
    }

    func localFallbackLLMConfig() throws -> LLMConfig? {
        guard usesICloud, let localDocumentsURL else { return nil }
        let url = localDocumentsURL.appendingPathComponent("TodoLite/config/llm_config.json")
        do {
            return try JSONDecoder().decode(LLMConfig.self, from: readDataCoordinated(at: url))
        } catch FileSystemError.fileNotFound { return nil }
        catch is DecodingError { throw FileSystemError.invalidFile(url.lastPathComponent) }
    }

    func clearLocalFallbackAPIKey(matching key: String) throws {
        guard usesICloud, let localDocumentsURL else { return }
        let url = localDocumentsURL.appendingPathComponent("TodoLite/config/llm_config.json")
        try coordinateWrite(at: url, options: .forReplacing) { coordinated in
            let config = try decode(LLMConfig.self, at: coordinated)
            // 源文件在迁移过程中变化时保留它，让下次重试重新读取。
            guard config.apiKey == key else { throw FileSystemError.readFailed }
            try JSONEncoder().encode(config).write(to: coordinated, options: .atomic)
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

    @discardableResult
    func setupDirectories() async throws -> LocalMigrationReport {
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

        return try migrateLocalFallbackDataIfNeeded()
    }

    private func createDirectoryIfNeeded(at url: URL) async throws {
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
            return
        }
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    // MARK: - Local Fallback Migration

    private func migrateLocalFallbackDataIfNeeded() throws -> LocalMigrationReport {
        var report = LocalMigrationReport()
        guard usesICloud, let localDocumentsURL else { return report }
        let localAppURL = localDocumentsURL.appendingPathComponent(appDirName, isDirectory: true)
        guard localAppURL.standardizedFileURL != (try appDirectory()).standardizedFileURL,
              FileManager.default.fileExists(atPath: localAppURL.path) else { return report }

        let directories = [tasksDirName, projectsDirName, tagsDirName, metaDirName,
                           configDirName, trashDirName, archiveDirName, conflictsDirName]
        for name in directories {
            let source = localAppURL.appendingPathComponent(name, isDirectory: true)
            guard FileManager.default.fileExists(atPath: source.path) else { continue }
            let destination = try appDirectory().appendingPathComponent(name, isDirectory: true)
            let files = try FileManager.default.contentsOfDirectory(at: source, includingPropertiesForKeys: [.isRegularFileKey])
            for file in files.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                let filename = file.lastPathComponent
                guard Self.isMigrationFile(filename, directory: name),
                      try file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true else { continue }
                let data = try normalizedMigrationData(readDataCoordinated(at: file), filename: filename, directory: name)
                var hasher = SHA256()
                hasher.update(data: Data((name + "/" + filename + "\0").utf8))
                hasher.update(data: data)
                let fingerprint = hasher.finalize().map { String(format: "%02x", $0) }.joined()
                let receiptName = "migration_" + fingerprint + ".json"
                do {
                    let receipt = try read(LocalMigrationReceipt.self, filename: receiptName, directory: .meta)
                    guard receipt.fingerprint == fingerprint else { throw FileSystemError.invalidFile(receiptName) }
                    continue
                } catch FileSystemError.fileNotFound { }

                let result: Int = try coordinateWrite(at: destination.appendingPathComponent(filename), options: .forReplacing) { url in
                    let existing: Data
                    do {
                        existing = try readData(at: url)
                    } catch FileSystemError.fileNotFound {
                        try data.write(to: url, options: .atomic)
                        return 1
                    }
                    if try normalizedMigrationData(existing, filename: filename, directory: name, isSource: false) == data { return 0 }
                    // 不覆盖云端同名文件；确定性备份名保证中断后重试也不会产生重复备份。
                    let backup = filename.replacingOccurrences(of: ".json", with: "")
                        + "_conflict_migration_" + fingerprint + ".json"
                    try writeCoordinated(data, to: conflictsDirectory().appendingPathComponent(backup))
                    return 2
                }
                try write(LocalMigrationReceipt(fingerprint: fingerprint), filename: receiptName, directory: .meta)
                if result == 1 { report.copiedFiles += 1 }
                if result == 2 { report.conflictFiles += 1 }
            }
        }
        return report
    }

    private static func isMigrationFile(_ filename: String, directory: String) -> Bool {
        guard filename.hasSuffix(".json") else { return false }
        switch directory {
        case "tasks": return filename.hasPrefix("task_")
        case "projects": return filename.hasPrefix("project_")
        case "tags": return filename.hasPrefix("tag_")
        case "meta": return filename.hasPrefix("focus_")
        case "config": return filename == "llm_config.json"
        default: return true
        }
    }

    private func normalizedMigrationData(_ data: Data, filename: String, directory: String, isSource: Bool = true) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let decoder = JSONDecoder()
        do {
            switch directory {
            case "tasks":
                let item = try decoder.decode(TodoItem.self, from: data)
                guard filename == "task_" + item.id + ".json" else { throw FileSystemError.invalidFile(filename) }
                return try encoder.encode(item)
            case "projects":
                let item = try decoder.decode(Project.self, from: data)
                guard filename == "project_" + item.id + ".json" else { throw FileSystemError.invalidFile(filename) }
                return try encoder.encode(item)
            case "tags":
                let item = try decoder.decode(TagItem.self, from: data)
                guard filename == "tag_" + item.id + ".json" else { throw FileSystemError.invalidFile(filename) }
                return try encoder.encode(item)
            case "meta":
                let item = try decoder.decode(FocusSet.self, from: data)
                guard filename == "focus_" + item.date + ".json" else { throw FileSystemError.invalidFile(filename) }
                return try encoder.encode(item)
            case "config":
                let config = try decoder.decode(LLMConfig.self, from: data)
                // Store 在迁移前先将旧密钥保存在本机 Keychain。
                // 禁止直接调用 setupDirectories 时悄悄丢弃尚未迁移的密钥。
                guard !isSource || config.apiKey.isEmpty else { throw FileSystemError.readFailed }
                return try encoder.encode(config)
            default:
                let object = try JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed)
                return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .fragmentsAllowed])
            }
        } catch let error as FileSystemError { throw error }
        catch { throw FileSystemError.invalidFile(filename) }
    }

    private func writeCoordinated(_ data: Data, to fileURL: URL) throws {
        try coordinateWrite(at: fileURL, options: .forReplacing) { url in
            do {
                try data.write(to: url, options: .atomic)
            } catch {
                throw FileSystemError.writeFailed
            }
        }
    }

    // MARK: - Coordinated I/O

    // NSFileCoordinator 的 accessor 是同步的。在回调结束后统一返回结果，
    // 避免 continuation 在 accessor 和 coordination error 两处重复 resume。
    private func coordinateWrite<T>(at url: URL, options: NSFileCoordinator.WritingOptions,
                                    operation: (URL) throws -> T) throws -> T {
        try requireDownloadedFile(at: url)
        var result: Result<T, Error>?
        var coordinationError: NSError?
        NSFileCoordinator().coordinate(writingItemAt: url, options: options, error: &coordinationError) { coordinatedURL in
            result = Result { try operation(coordinatedURL) }
        }
        if coordinationError != nil { throw FileSystemError.writeFailed }
        guard let result else { throw FileSystemError.writeFailed }
        return try result.get()
    }

    private static func classifyReadError(_ error: Error, filename: String) -> FileSystemError {
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain,
           [NSFileReadNoSuchFileError, NSFileNoSuchFileError].contains(nsError.code) {
            return .fileNotFound(filename)
        }
        return .readFailed
    }

    private func requireDownloadedFile(at url: URL) throws {
        let placeholder = url.deletingLastPathComponent().appendingPathComponent("." + url.lastPathComponent + ".icloud")
        let status = try? url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey]).ubiquitousItemDownloadingStatus
        if FileManager.default.fileExists(atPath: placeholder.path) || status == .notDownloaded {
            try? FileManager.default.startDownloadingUbiquitousItem(at: url)
            throw FileSystemError.downloadPending(url.lastPathComponent)
        }
    }

    private func readData(at url: URL) throws -> Data {
        try requireDownloadedFile(at: url)
        do { return try Data(contentsOf: url) }
        catch { throw Self.classifyReadError(error, filename: url.lastPathComponent) }
    }

    private func readDataCoordinated(at url: URL) throws -> Data {
        try requireDownloadedFile(at: url)
        var result: Result<Data, Error>?
        var coordinationError: NSError?
        NSFileCoordinator().coordinate(readingItemAt: url, options: .withoutChanges, error: &coordinationError) { coordinated in
            result = Result { try readData(at: coordinated) }
        }
        if let coordinationError { throw Self.classifyReadError(coordinationError, filename: url.lastPathComponent) }
        guard let result else { throw FileSystemError.readFailed }
        return try result.get()
    }

    private func decode<T: Decodable>(_ type: T.Type, at url: URL) throws -> T {
        let data = try readData(at: url)
        do { return try JSONDecoder().decode(type, from: data) }
        catch { throw FileSystemError.invalidFile(url.lastPathComponent) }
    }

    func write<T: Encodable>(_ value: T, filename: String, directory: FileDirectory) throws {
        let fileURL = try directoryURL(directory).appendingPathComponent(filename)
        let data = try JSONEncoder().encode(value)
        try writeCoordinated(data, to: fileURL)
    }

    func read<T: Decodable>(_ type: T.Type, filename: String, directory: FileDirectory) throws -> T {
        let fileURL = try directoryURL(directory).appendingPathComponent(filename)
        try requireDownloadedFile(at: fileURL)
        var result: Result<T, Error>?
        var coordinationError: NSError?
        NSFileCoordinator().coordinate(readingItemAt: fileURL, options: .withoutChanges, error: &coordinationError) { coordinatedURL in
            result = Result { try decode(type, at: coordinatedURL) }
        }
        if let coordinationError { throw Self.classifyReadError(coordinationError, filename: filename) }
        guard let result else { throw FileSystemError.readFailed }
        return try result.get()
    }

    /// 读、校验和写入处于同一次文件协调内，且中间没有 actor 挂起点。
    func update<T: Codable>(_ type: T.Type, filename: String, directory: FileDirectory,
                            transform: (T?) throws -> T) throws -> T {
        let fileURL = try directoryURL(directory).appendingPathComponent(filename)
        return try coordinateWrite(at: fileURL, options: .forReplacing) { url in
            guard NSFileVersion.unresolvedConflictVersionsOfItem(at: url)?.isEmpty != false else {
                throw FileSystemError.conflictDetected
            }
            let existing: T?
            do {
                existing = try decode(type, at: url)
            } catch FileSystemError.fileNotFound {
                existing = nil
            }
            let updated = try transform(existing)
            let data = try JSONEncoder().encode(updated)
            do {
                try data.write(to: url, options: .atomic)
            } catch {
                throw FileSystemError.writeFailed
            }
            return updated
        }
    }

    /// 幂等创建：已有文件只读取，不改写。供同一草稿的失败重试使用。
    func insertOrRead<T: Codable>(_ value: T, filename: String, directory: FileDirectory) throws -> T {
        let fileURL = try directoryURL(directory).appendingPathComponent(filename)
        return try coordinateWrite(at: fileURL, options: []) { url in
            guard NSFileVersion.unresolvedConflictVersionsOfItem(at: url)?.isEmpty != false else {
                throw FileSystemError.conflictDetected
            }
            do { return try decode(T.self, at: url) }
            catch FileSystemError.fileNotFound { }
            do { try JSONEncoder().encode(value).write(to: url, options: .atomic) }
            catch { throw FileSystemError.writeFailed }
            return value
        }
    }

    /// 保存成功后才删除源文件；中断时最多保留两份数据，不会丢失任务。
    func trashTodo(filename: String) throws {
        let source = try directoryURL(.tasks).appendingPathComponent(filename)
        let snapshot = try read(TodoItem.self, filename: filename, directory: .tasks)
        let entry = DeletedTodo(todo: snapshot, deletedAt: Date())
        try TodoBackup(todos: [], projects: [], tags: [], focusSets: [], deletedTodos: [entry]).validate()
        let destination = try directoryURL(.trash).appendingPathComponent(entry.filename)
        try requireDownloadedFile(at: source)
        try requireDownloadedFile(at: destination)
        var result: Result<Void, Error>?
        var coordinationError: NSError?
        // 两个写入目标一次协调，避免在单文件写协调中嵌套新的写协调。
        NSFileCoordinator().coordinate(writingItemAt: source, options: .forDeleting,
                                       writingItemAt: destination, options: [], error: &coordinationError) { sourceURL, destinationURL in
            result = Result {
                guard NSFileVersion.unresolvedConflictVersionsOfItem(at: sourceURL)?.isEmpty != false,
                      NSFileVersion.unresolvedConflictVersionsOfItem(at: destinationURL)?.isEmpty != false,
                      try decode(TodoItem.self, at: sourceURL) == snapshot else {
                    throw FileSystemError.conflictDetected
                }
                do { try JSONEncoder().encode(entry).write(to: destinationURL, options: .atomic) }
                catch { throw FileSystemError.writeFailed }
                do { try FileManager.default.removeItem(at: sourceURL) }
                catch { throw FileSystemError.deleteFailed }
            }
        }
        if coordinationError != nil { throw FileSystemError.writeFailed }
        guard let result else { throw FileSystemError.writeFailed }
        try result.get()
    }

    /// 恢复采用仅新增语义，存在的文件（包括损坏文件和云端占位文件）不会被覆盖。
    func insertIfMissing<T: Encodable>(_ value: T, filename: String, directory: FileDirectory) throws -> Bool {
        let fileURL = try directoryURL(directory).appendingPathComponent(filename)
        return try coordinateWrite(at: fileURL, options: .forReplacing) { url in
            if FileManager.default.fileExists(atPath: url.path) { return false }
            do { try JSONEncoder().encode(value).write(to: url, options: .atomic) }
            catch { throw FileSystemError.writeFailed }
            return true
        }
    }

    func delete(filename: String, directory: FileDirectory) throws {
        let fileURL = try directoryURL(directory).appendingPathComponent(filename)
        try coordinateWrite(at: fileURL, options: .forDeleting) { url in
            do {
                try FileManager.default.removeItem(at: url)
            } catch {
                throw FileSystemError.deleteFailed
            }
        }
    }

    func backupSnapshot() async throws -> [BackupSnapshotFile] {
        try await BackupSnapshotCapture(root: appDirectory()).capture()
    }

    // MARK: - List

    func listFiles(in directory: FileDirectory) async throws -> [String] {
        let dirURL = try directoryURL(directory)

        guard FileManager.default.fileExists(atPath: dirURL.path) else {
            return []
        }

        let contents = try FileManager.default.contentsOfDirectory(at: dirURL, includingPropertiesForKeys: nil)
        // 占位文件也属于数据集合，读取时应提示等待下载，不能悄悄漏掉。
        return Array(Set(contents.map { url in
            let name = url.lastPathComponent
            if name.hasPrefix("."), name.hasSuffix(".icloud") {
                return String(name.dropFirst().dropLast(".icloud".count))
            }
            return name
        })).sorted()
    }

    // MARK: - Conflict Backup

    func writeConflictBackup(filename: String, data: Data) async throws {
        let dir = try conflictsDirectory()
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let name = filename.replacingOccurrences(of: ".json", with: "") + "_conflict_" + timestamp + "_" + UUID().uuidString + ".json"
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
