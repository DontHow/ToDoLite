import SwiftUI

struct ConflictReviewView: View {
    let record: ConflictRecord
    @State private var store = TodoStore.shared
    @State private var busy = false
    @State private var message: String?

    private var current: ConflictPayload? {
        switch record.payload {
        case .todo(let item): return store.todos.first { $0.id == item.id }.map(ConflictPayload.todo)
        case .project(let item): return store.projects.first { $0.id == item.id }.map(ConflictPayload.project)
        case .tag(let item): return store.tags.first { $0.id == item.id }.map(ConflictPayload.tag)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("比较后可将冲突内容恢复为独立副本。当前记录和原冲突文件都会保留，重复恢复会复用同一副本。")
                    .foregroundStyle(.secondary)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), alignment: .top)], alignment: .leading, spacing: 16) {
                    comparisonCard(title: "冲突副本", payload: record.payload, comparing: current)
                    if let current {
                        comparisonCard(title: "当前记录", payload: current, comparing: nil)
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("当前记录").appFont(.headline)
                            Text("当前记录已不存在，仍可恢复为独立副本。")
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                    }
                }
                Text("来源文件：\(record.filename)")
                    .appFont(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                if case .project = record.payload {
                    Text("恢复为新项目后，现有任务的项目关联保持原状。")
                        .appFont(.caption).foregroundStyle(.secondary)
                }
                if case .tag = record.payload {
                    Text("恢复为新标签后，现有任务的标签关联保持原状。")
                        .appFont(.caption).foregroundStyle(.secondary)
                }
                Button {
                    guard !busy else { return }
                    busy = true
                    Task { @MainActor in
                        defer { busy = false }
                        do {
                            try await store.restoreConflictAsCopy(record)
                            message = "独立\(record.payload.kind)副本已恢复。若此前已恢复，则保留该副本的当前内容。"
                        } catch { message = error.localizedDescription }
                    }
                } label: {
                    HStack {
                        if busy { ProgressView().controlSize(.small) }
                        Text("恢复为独立\(record.payload.kind)副本")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(busy)
            }
            .padding(20)
            .frame(maxWidth: 1000, alignment: .leading)
        }
        .navigationTitle("冲突比较")
        .task {
            let directory: String
            switch record.payload {
            case .todo: directory = "tasks"
            case .project: directory = "projects"
            case .tag: directory = "tags"
            }
            await store.refreshRecordFromDisk(id: record.payload.sourceID, directory: directory)
        }
        .alert("冲突恢复", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("好") { message = nil }
        } message: { Text(message ?? "") }
    }

    private func comparisonCard(title: String, payload: ConflictPayload, comparing other: ConflictPayload?) -> some View {
        let comparison = other.map { Dictionary(uniqueKeysWithValues: fields($0).map { ($0.label, $0.comparisonValue) }) } ?? [:]
        return VStack(alignment: .leading, spacing: 14) {
            Text(title).appFont(.headline)
            ForEach(fields(payload)) { field in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(field.label).appFont(.caption).foregroundStyle(.secondary)
                        if let value = comparison[field.label], value != field.comparisonValue {
                            Text("与当前不同").appFont(.caption).foregroundStyle(.orange)
                        }
                    }
                    Text(field.value).textSelection(.enabled)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func fields(_ payload: ConflictPayload) -> [ComparisonField] {
        func date(_ value: Date?) -> String {
            value?.formatted(date: .abbreviated, time: .shortened) ?? "未设置"
        }
        switch payload {
        case .todo(let item):
            let project = item.projectId.map { id in
                store.projects.first { $0.id == id }?.name ?? "项目不存在（\(id)）"
            } ?? "无"
            let tags = item.tagIds.map { id in store.tags.first { $0.id == id }?.name ?? "标签不存在（\(id)）" }
            return [
                .init(label: "标题", value: item.title),
                .init(label: "描述", value: item.description.isEmpty ? "无" : item.description, rawValue: item.description),
                .init(label: "状态", value: item.status.displayName),
                .init(label: "项目", value: project, rawValue: item.projectId ?? ""),
                .init(label: "标签", value: tags.isEmpty ? "无" : tags.joined(separator: "、"), rawValue: item.tagIds.joined(separator: ",")),
                .init(label: "截止日期", value: date(item.dueAt), rawValue: item.dueAt?.timeIntervalSinceReferenceDate.description ?? "nil"),
                .init(label: "计划日期", value: date(item.scheduledAt), rawValue: item.scheduledAt?.timeIntervalSinceReferenceDate.description ?? "nil"),
                .init(label: "完成时间", value: date(item.completedAt), rawValue: item.completedAt?.timeIntervalSinceReferenceDate.description ?? "nil"),
                .init(label: "创建时间", value: date(item.createdAt), rawValue: item.createdAt.timeIntervalSinceReferenceDate.description),
                .init(label: "更新时间", value: date(item.updatedAt), rawValue: item.updatedAt.timeIntervalSinceReferenceDate.description),
                .init(label: "版本", value: String(item.version))
            ]
        case .project(let item):
            return [
                .init(label: "名称", value: item.name),
                .init(label: "图标", value: item.emoji),
                .init(label: "颜色", value: item.colorHex),
                .init(label: "已归档", value: item.isArchived ? "是" : "否"),
                .init(label: "创建时间", value: date(item.createdAt), rawValue: item.createdAt.timeIntervalSinceReferenceDate.description),
                .init(label: "更新时间", value: date(item.updatedAt), rawValue: item.updatedAt.timeIntervalSinceReferenceDate.description)
            ]
        case .tag(let item):
            return [.init(label: "名称", value: item.name), .init(label: "颜色", value: item.colorHex)]
        }
    }
}

private struct ComparisonField: Identifiable {
    var label: String
    var value: String
    var rawValue: String? = nil
    var comparisonValue: String { rawValue ?? value }
    var id: String { label }
}
