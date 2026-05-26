import Foundation

final class iCloudSyncManager {
    static let shared = iCloudSyncManager()

    private let query = NSMetadataQuery()
    private let store = TodoStore.shared

    private var isMonitoring = false

    private init() {}

    // MARK: - Start/Stop

    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true

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
        isMonitoring = false
    }

    // MARK: - Handlers

    @objc private func queryDidFinishGathering(_ notification: Notification) {
        query.disableUpdates()
        processQueryResults()
        query.enableUpdates()
    }

    @objc private func queryDidUpdate(_ notification: Notification) {
        query.disableUpdates()
        processQueryResults()
        query.enableUpdates()
    }

    private func processQueryResults() {
        guard let results = query.results as? [NSMetadataItem] else { return }

        for item in results {
            guard let url = item.value(forAttribute: NSMetadataItemURLKey) as? URL else { continue }
            guard let filename = item.value(forAttribute: NSMetadataItemFSNameKey) as? String else { continue }

            // Skip conflict files
            if filename.contains("_conflict_") { continue }

            let status = item.value(forAttribute: NSMetadataUbiquitousItemDownloadingStatusKey) as? String
            let isDownloaded = status == NSMetadataUbiquitousItemDownloadingStatusCurrent

            guard isDownloaded else { continue }

            let dir = url.deletingLastPathComponent().lastPathComponent

            Task {
                do {
                    switch dir {
                    case "tasks":
                        let todo = try await FileSystemManager.shared.read(TodoItem.self, filename: filename, directory: .tasks)
                        await updateTodoInStore(todo)
                    case "projects":
                        let project = try await FileSystemManager.shared.read(Project.self, filename: filename, directory: .projects)
                        await updateProjectInStore(project)
                    case "tags":
                        let tag = try await FileSystemManager.shared.read(TagItem.self, filename: filename, directory: .tags)
                        await updateTagInStore(tag)
                    default:
                        break
                    }
                } catch {
                    // File may have been deleted or unreadable
                }
            }
        }
    }

    // MARK: - Store Updates

    @MainActor
    private func updateTodoInStore(_ todo: TodoItem) {
        if let idx = store.todos.firstIndex(where: { $0.id == todo.id }) {
            if store.todos[idx].version < todo.version {
                store.todos[idx] = todo
            }
        } else {
            store.todos.append(todo)
        }
    }

    @MainActor
    private func updateProjectInStore(_ project: Project) {
        if let idx = store.projects.firstIndex(where: { $0.id == project.id }) {
            store.projects[idx] = project
        } else {
            store.projects.append(project)
        }
    }

    @MainActor
    private func updateTagInStore(_ tag: TagItem) {
        if let idx = store.tags.firstIndex(where: { $0.id == tag.id }) {
            store.tags[idx] = tag
        } else {
            store.tags.append(tag)
        }
    }
}
