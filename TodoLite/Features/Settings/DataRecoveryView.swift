import SwiftUI
import UniformTypeIdentifiers

private struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw RecoveryError.invalidBackup }
        self.data = data
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct DataRecoveryView: View {
    @State private var store = TodoStore.shared
    @State private var entries: [DeletedTodo] = []
    @State private var conflicts: [ConflictRecord] = []
    @State private var busy = false
    @State private var message: String?
    @State private var document: BackupDocument?
    @State private var exporting = false
    @State private var importing = false

    var body: some View {
        List {
            Section {
                Button("导出数据备份", systemImage: "square.and.arrow.up") {
                    perform {
                        document = BackupDocument(data: try await store.exportBackup())
                        exporting = true
                    }
                }
                Button("从备份恢复缺失数据", systemImage: "square.and.arrow.down") { importing = true }
            } header: {
                Text("数据备份")
            } footer: {
                Text("包含任务、项目、标签、历史关注、回收站和这三类记录的冲突副本，不包含 AI 配置和 API Key。单份备份最大 50 MB。恢复只新增缺失记录，保留当前已有内容；中断后可重新导入同一备份继续恢复。")
            }
            Section {
                if conflicts.isEmpty {
                    Text("暂无任务、项目或标签冲突").foregroundStyle(.secondary)
                }
                ForEach(conflicts) { conflict in
                    NavigationLink(destination: ConflictReviewView(record: conflict)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(conflict.payload.title).appFont(.body)
                            Text("\(conflict.payload.kind) · 查看、比较与恢复")
                                .appFont(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Text("冲突副本")
            } footer: {
                Text("恢复会创建独立副本，保留当前内容与原冲突文件。当前支持任务、项目和标签；配置等其他冲突文件继续保存在原目录。")
            }
            Section {
                if entries.isEmpty {
                    Text("回收站为空").foregroundStyle(.secondary)
                }
                ForEach(entries) { entry in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.todo.title).appFont(.body)
                            Text("删除于 \(entry.deletedAt.formatted(date: .abbreviated, time: .shortened))")
                                .appFont(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("恢复") {
                            perform {
                                try await store.restoreTodo(entry)
                                entries = try await store.deletedTodos()
                                message = "已恢复任务。"
                            }
                        }
                    }
                }
            } header: {
                Text("回收站")
            } footer: {
                Text("删除的任务会保留在这里，可恢复原来的状态和日期。归档任务请在“已归档”中查看。")
            }
        }
        .navigationTitle("回收站与备份")
        .disabled(busy)
        .overlay { if busy { ProgressView() } }
        .task { await reload() }
        .refreshable { await reload() }
        .alert("数据管理", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("好") { message = nil }
        } message: { Text(message ?? "") }
        .fileExporter(isPresented: $exporting, document: document, contentType: .json,
                      defaultFilename: "TodoLite-\(FocusSet.todayString())") { result in
            if case let .failure(error) = result { message = error.localizedDescription }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            switch result {
            case let .success(url):
                perform {
                    let report = try await store.importBackup(from: url)
                    entries = try await store.deletedTodos()
                    conflicts = try await store.conflictRecords()
                    message = report.message
                }
            case let .failure(error): message = error.localizedDescription
            }
        }
    }

    private func perform(_ action: @escaping @MainActor () async throws -> Void) {
        guard !busy else { return }
        busy = true
        Task { @MainActor in
            defer { busy = false }
            do { try await action() }
            catch {
                message = error.localizedDescription
                if let refreshed = try? await store.deletedTodos() { entries = refreshed }
            }
        }
    }

    private func reload() async {
        do {
            entries = try await store.deletedTodos()
            conflicts = try await store.conflictRecords()
        }
        catch { message = error.localizedDescription }
    }
}
