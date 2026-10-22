import Foundation

@MainActor
final class iCloudSyncManager {
    static let shared = iCloudSyncManager()

    private let query = NSMetadataQuery()
    private let store = TodoStore.shared
    private var rootURL: URL?

    private var isMonitoring = false
    private var pendingRemovalTasks: [String: Task<Void, Never>] = [:]

    private init() {}

    // MARK: - Start/Stop

    func startMonitoring() async {
        guard !isMonitoring else { return }
        // 本地回退时不监听其他 iCloud 容器；后续事件也必须位于当前应用目录中。
        guard let root = try? await FileSystemManager.shared.cloudAppDirectory() else { return }
        guard !isMonitoring else { return }
        rootURL = root
        isMonitoring = true

        query.operationQueue = .main
        query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        query.predicate = NSPredicate(
            format: "%K LIKE[c] %@",
            NSMetadataItemFSNameKey,
            "*.json"
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(queryDidFinishGathering),
            name: .NSMetadataQueryDidFinishGathering,
            object: query
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(queryDidUpdate),
            name: .NSMetadataQueryDidUpdate,
            object: query
        )

        if !query.start() {
            NotificationCenter.default.removeObserver(self)
            isMonitoring = false
            store.operationError = "无法启动 iCloud 同步监控，请重新打开应用后重试。"
        }
    }

    func stopMonitoring() {
        query.stop()
        NotificationCenter.default.removeObserver(self)
        pendingRemovalTasks.values.forEach { $0.cancel() }
        pendingRemovalTasks.removeAll()
        isMonitoring = false
    }

    // MARK: - Handlers

    @objc private func queryDidFinishGathering(_ notification: Notification) {
        query.disableUpdates()
        processItems(query.results as? [NSMetadataItem] ?? [])
        query.enableUpdates()
    }

    @objc private func queryDidUpdate(_ notification: Notification) {
        query.disableUpdates()
        processRemovedItems(from: notification)
        processChangedItems(from: notification)
        query.enableUpdates()
    }

    private func processChangedItems(from notification: Notification) {
        let added = notification.userInfo?[NSMetadataQueryUpdateAddedItemsKey] as? [NSMetadataItem] ?? []
        let changed = notification.userInfo?[NSMetadataQueryUpdateChangedItemsKey] as? [NSMetadataItem] ?? []
        processItems(added + changed)
    }

    private func processItems(_ items: [NSMetadataItem]) {
        for item in items {
            guard let url = item.value(forAttribute: NSMetadataItemURLKey) as? URL else { continue }
            guard let filename = item.value(forAttribute: NSMetadataItemFSNameKey) as? String,
                  let rootURL, Self.isApplicationItem(url, rootURL: rootURL) else { continue }

            cancelPendingRemoval(for: url)

            // Skip conflict files
            if filename.contains("_conflict_") { continue }

            let status = item.value(forAttribute: NSMetadataUbiquitousItemDownloadingStatusKey) as? String
            let isDownloaded = status == NSMetadataUbiquitousItemDownloadingStatusCurrent

            guard isDownloaded else {
                let downloadRequested = item.value(
                    forAttribute: NSMetadataUbiquitousItemDownloadRequestedKey
                ) as? Bool ?? false
                if Self.shouldRequestDownload(status: status, alreadyRequested: downloadRequested) {
                    do { try FileManager.default.startDownloadingUbiquitousItem(at: url) }
                    catch { store.operationError = "iCloud 文件下载失败：" + error.localizedDescription }
                }
                continue
            }

            let dir = url.deletingLastPathComponent().lastPathComponent

            Task { @MainActor in
                do {
                    switch dir {
                    case "tasks":
                        if let id = Self.id(from: filename, prefix: "task_") {
                            await store.refreshRecordFromDisk(id: id, directory: dir)
                        }
                    case "projects":
                        if let id = Self.id(from: filename, prefix: "project_") {
                            await store.refreshRecordFromDisk(id: id, directory: dir)
                        }
                    case "tags":
                        if let id = Self.id(from: filename, prefix: "tag_") {
                            await store.refreshRecordFromDisk(id: id, directory: dir)
                        }
                    case "meta" where filename == FocusRepository.filename(for: Date()):
                        let focus = try await FileSystemManager.shared.read(FocusSet.self, filename: filename, directory: .meta)
                        store.applyExternalFocus(focus)
                    case "config" where filename == "llm_config.json":
                        try await store.reloadLLMConfig()
                    default:
                        break
                    }
                } catch FileSystemError.fileNotFound {
                    // 文件在读取前被删除时，交给 removal 通知处理。
                } catch {
                    store.operationError = "iCloud 同步读取失败：" + error.localizedDescription
                }
            }
        }
    }

    private func processRemovedItems(from notification: Notification) {
        guard let items = notification.userInfo?[NSMetadataQueryUpdateRemovedItemsKey] as? [NSMetadataItem] else {
            return
        }

        for item in items {
            guard let url = item.value(forAttribute: NSMetadataItemURLKey) as? URL,
                  let rootURL, Self.isApplicationItem(url, rootURL: rootURL) else { continue }
            let filename = url.lastPathComponent
            let directory = url.deletingLastPathComponent().lastPathComponent

            scheduleRemoval(for: url, filename: filename, directory: directory)
        }
    }

    private func scheduleRemoval(for url: URL, filename: String, directory: String) {
        let key = url.standardizedFileURL.path
        pendingRemovalTasks[key]?.cancel()
        pendingRemovalTasks[key] = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled, let self else { return }
            defer { pendingRemovalTasks[key] = nil }

            // Atomic replacement can briefly appear as a removal followed by an addition.
            guard Self.shouldRemoveExternalItem(fileExists: FileManager.default.fileExists(atPath: url.path)) else {
                return
            }

            await removeExternalItem(filename: filename, directory: directory)
        }
    }

    private func cancelPendingRemoval(for url: URL) {
        let key = url.standardizedFileURL.path
        pendingRemovalTasks[key]?.cancel()
        pendingRemovalTasks[key] = nil
    }

    private func removeExternalItem(filename: String, directory: String) async {
        switch directory {
        case "tasks":
            if let id = Self.id(from: filename, prefix: "task_") {
                await store.refreshRecordFromDisk(id: id, directory: directory)
            }
        case "projects":
            if let id = Self.id(from: filename, prefix: "project_") {
                await store.refreshRecordFromDisk(id: id, directory: directory)
            }
        case "tags":
            if let id = Self.id(from: filename, prefix: "tag_") {
                await store.refreshRecordFromDisk(id: id, directory: directory)
            }
        case "meta" where filename == FocusRepository.filename(for: Date()):
            store.applyExternalFocus(FocusSet())
        default:
            break
        }
    }

    private static func id(from filename: String, prefix: String) -> String? {
        guard filename.hasPrefix(prefix), filename.hasSuffix(".json") else { return nil }
        return String(filename.dropFirst(prefix.count).dropLast(5))
    }

    nonisolated static func isApplicationItem(_ url: URL, rootURL: URL) -> Bool {
        let parent = url.standardizedFileURL.deletingLastPathComponent()
        let root = rootURL.standardizedFileURL
        guard parent.deletingLastPathComponent() == root else { return false }
        let filename = url.lastPathComponent
        guard filename.hasSuffix(".json"), !filename.contains("_conflict_") else { return false }
        switch parent.lastPathComponent {
        case "tasks": return filename.hasPrefix("task_")
        case "projects": return filename.hasPrefix("project_")
        case "tags": return filename.hasPrefix("tag_")
        case "meta": return filename.hasPrefix("focus_")
        case "config": return filename == "llm_config.json"
        default: return false
        }
    }

    nonisolated static func shouldRequestDownload(status: String?, alreadyRequested: Bool) -> Bool {
        status == NSMetadataUbiquitousItemDownloadingStatusNotDownloaded && !alreadyRequested
    }

    nonisolated static func shouldRemoveExternalItem(fileExists: Bool) -> Bool {
        !fileExists
    }

}
