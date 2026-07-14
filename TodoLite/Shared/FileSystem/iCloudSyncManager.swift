import Foundation

@MainActor
final class iCloudSyncManager {
    static let shared = iCloudSyncManager()

    private let query = NSMetadataQuery()
    private let store = TodoStore.shared

    private var isMonitoring = false
    private var pendingRemovalTasks: [String: Task<Void, Never>] = [:]

    private init() {}

    // MARK: - Start/Stop

    func startMonitoring() {
        guard !isMonitoring else { return }
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

        query.start()
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
            guard let filename = item.value(forAttribute: NSMetadataItemFSNameKey) as? String else { continue }

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
                    try? FileManager.default.startDownloadingUbiquitousItem(at: url)
                }
                continue
            }

            let dir = url.deletingLastPathComponent().lastPathComponent

            Task { @MainActor in
                do {
                    switch dir {
                    case "tasks":
                        let todo = try await FileSystemManager.shared.read(TodoItem.self, filename: filename, directory: .tasks)
                        await store.applyExternalTodo(todo)
                    case "projects":
                        let project = try await FileSystemManager.shared.read(Project.self, filename: filename, directory: .projects)
                        await store.applyExternalProject(project)
                    case "tags":
                        let tag = try await FileSystemManager.shared.read(TagItem.self, filename: filename, directory: .tags)
                        await store.applyExternalTag(tag)
                    case "meta" where filename == FocusRepository.filename(for: Date()):
                        let focus = try await FileSystemManager.shared.read(FocusSet.self, filename: filename, directory: .meta)
                        store.applyExternalFocus(focus)
                    default:
                        break
                    }
                } catch {
                    // File may have been deleted or unreadable
                }
            }
        }
    }

    private func processRemovedItems(from notification: Notification) {
        guard let items = notification.userInfo?[NSMetadataQueryUpdateRemovedItemsKey] as? [NSMetadataItem] else {
            return
        }

        for item in items {
            guard let url = item.value(forAttribute: NSMetadataItemURLKey) as? URL else { continue }
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
                await store.removeExternalTodo(id: id)
            }
        case "projects":
            if let id = Self.id(from: filename, prefix: "project_") {
                await store.removeExternalProject(id: id)
            }
        case "tags":
            if let id = Self.id(from: filename, prefix: "tag_") {
                await store.removeExternalTag(id: id)
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

    nonisolated static func shouldRequestDownload(status: String?, alreadyRequested: Bool) -> Bool {
        status == NSMetadataUbiquitousItemDownloadingStatusNotDownloaded && !alreadyRequested
    }

    nonisolated static func shouldRemoveExternalItem(fileExists: Bool) -> Bool {
        !fileExists
    }

}
