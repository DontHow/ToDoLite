import Foundation

struct BackupSnapshotFile: Sendable {
    let directory: String
    let filename: String
    let data: Data
}

/// 同时取得所有已有数据文件的读权限，并检查读取期间文件集合没有变化。
final class BackupSnapshotCapture: @unchecked Sendable {
    private struct Entry: Equatable {
        let directory: String
        let filename: String
        let url: URL
    }
    private let root: URL
    private let coordinator = NSFileCoordinator()
    private let queue = OperationQueue()

    init(root: URL) { self.root = root }

    func capture() async throws -> [BackupSnapshotFile] {
        let entries = try Self.inventory(root: root)
        if entries.isEmpty { return [] }
        let intents = entries.map { NSFileAccessIntent.readingIntent(with: $0.url, options: .withoutChanges) }
        return try await withCheckedThrowingContinuation { continuation in
            coordinator.coordinate(with: intents, queue: queue) { [self] error in
                if let error {
                    let nsError = error as NSError
                    let missing = nsError.domain == NSCocoaErrorDomain && [NSFileReadNoSuchFileError, NSFileNoSuchFileError].contains(nsError.code)
                    continuation.resume(throwing: missing ? RecoveryError.backupChanged : error)
                    return
                }
                do {
                    var files: [BackupSnapshotFile] = []
                    var remaining = BackupCoding.maximumBytes
                    for (entry, intent) in zip(entries, intents) {
                        let data = try BackupCoding.readData(from: intent.url, maximumBytes: remaining)
                        remaining -= data.count
                        files.append(BackupSnapshotFile(directory: entry.directory, filename: entry.filename, data: data))
                    }
                    guard try Self.inventory(root: root) == entries else { throw RecoveryError.backupChanged }
                    continuation.resume(returning: files)
                } catch { continuation.resume(throwing: error) }
            }
        }
    }

    private static func inventory(root: URL) throws -> [Entry] {
        var entries: [Entry] = []
        for directory in ["tasks", "projects", "tags", "meta", "trash", "conflicts"] {
            let folder = root.appendingPathComponent(directory, isDirectory: true)
            guard FileManager.default.fileExists(atPath: folder.path) else { continue }
            let urls = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
            var names = Set<String>()
            for url in urls {
                var name = url.lastPathComponent
                let placeholder = name.hasPrefix(".") && name.hasSuffix(".icloud")
                if placeholder { name = String(name.dropFirst().dropLast(".icloud".count)) }
                guard name.hasSuffix(".json"), directory != "meta" || name.hasPrefix("focus_"),
                      directory != "trash" || name.hasPrefix("deleted_"),
                      directory != "conflicts" || ConflictRecord.supports(name) else { continue }
                let logicalURL = folder.appendingPathComponent(name)
                let status = try? logicalURL.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey]).ubiquitousItemDownloadingStatus
                if placeholder || status == .notDownloaded {
                    try? FileManager.default.startDownloadingUbiquitousItem(at: logicalURL)
                    throw FileSystemError.downloadPending(name)
                }
                if names.insert(name).inserted { entries.append(Entry(directory: directory, filename: name, url: logicalURL)) }
            }
        }
        return entries.sorted { $0.url.path < $1.url.path }
    }
}
