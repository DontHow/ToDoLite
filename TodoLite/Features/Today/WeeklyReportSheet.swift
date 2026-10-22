import SwiftUI

struct WeeklyReportSheet: View {
    let week: ReportWeek
    let todos: [TodoItem]
    let projects: [Project]

    @Environment(\.dismiss) private var dismiss
    @State private var store = TodoStore.shared
    @State private var selectedSources: Set<AIActivitySource> = []
    @State private var previewSources: Set<AIActivitySource> = []
    @State private var previewText = ""
    @State private var reportText = ""
    @State private var isPreparing = true
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var generationTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(week.title())
                        .appFont(.title3, weight: .semibold)
                    if !reportText.isEmpty {
                        Text(reportText)
                            .appFont(.body)
                            .lineSpacing(4)
                            .textSelection(.enabled)
                        HStack {
                            Button("复制周报", systemImage: "doc.on.doc", action: copyToClipboard)
                            Button("返回编辑") { reportText = "" }
                        }
                    } else {
                        #if os(macOS)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("补充本机工作记录（可选）").appFont(.headline)
                            ForEach(AIActivitySource.allCases) { source in
                                Toggle(source.title, isOn: Binding(
                                    get: { selectedSources.contains(source) },
                                    set: { if $0 { selectedSources.insert(source) } else { selectedSources.remove(source) } }
                                ))
                            }
                            Text("仅纳入所选周的可识别记录。切换来源会重新生成预览，替换手动修改，请在发送前确认内容。")
                                .appFont(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .disabled(isLoading)
                        #endif

                        Text("待发送内容，可编辑").appFont(.headline)
                        if isPreparing { ProgressView("正在准备预览…") }
                        TextEditor(text: $previewText)
                            .appFont(.body)
                            .frame(minHeight: 240)
                            .padding(8)
                            .background(Color.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .disabled(isPreparing || isLoading)
                        Text("将发送至 \(store.llmConfig.baseURL) · \(store.llmConfig.model)")
                            .appFont(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                        if let errorMessage {
                            Text(errorMessage).foregroundStyle(.red).appFont(.callout)
                        }
                        Button {
                            guard generationTask == nil else { return }
                            generationTask = Task {
                                defer { generationTask = nil }
                                await generateReport()
                            }
                        } label: {
                            HStack {
                                if isLoading { ProgressView().controlSize(.small) }
                                Text(isLoading ? "正在生成…" : "发送并生成周报")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isLoading || isPreparing || previewSources != selectedSources || previewText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .padding(20)
            }
            .navigationTitle("周报")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 600, idealWidth: 760, minHeight: 500, idealHeight: 640)
        #endif
        .task(id: selectedSources) { await refreshPreview() }
        .onDisappear { generationTask?.cancel() }
    }

    @MainActor
    private func refreshPreview() async {
        isPreparing = true
        errorMessage = nil
        let sources = selectedSources
        let activity: String
        #if os(macOS)
        activity = await AIActivityReader.summaryAsync(week: week, sources: sources)
        #else
        activity = ""
        #endif
        guard !Task.isCancelled else { return }
        previewText = WeeklyReportPrompt.build(week: week, todos: todos, projects: projects,
                                              template: store.llmConfig.reportTemplate, activity: activity)
        previewSources = sources
        if !sources.isEmpty && activity.isEmpty {
            errorMessage = "未找到该周可识别的记录，可直接编辑预览内容。"
        }
        isPreparing = false
    }

    @MainActor
    private func generateReport() async {
        guard !isLoading, !isPreparing, previewSources == selectedSources else { return }
        let config = store.llmConfig
        guard !config.apiKey.isEmpty else { errorMessage = "请先在设置中配置 LLM API"; return }
        let prompt = previewText
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let response = try await LLMService.shared.chat(messages: [
                LLMChatMessage(role: "system", content: "你是一位专业的职场助理，根据用户提供的材料生成简洁、准确的工作周报，使用中文。"),
                LLMChatMessage(role: "user", content: prompt)
            ], config: config)
            guard !Task.isCancelled else { return }
            reportText = response
        } catch {
            guard !Task.isCancelled else { return }
            errorMessage = error.localizedDescription
        }
    }

    private func copyToClipboard() {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(reportText, forType: .string)
        #else
        UIPasteboard.general.string = reportText
        #endif
    }
}
