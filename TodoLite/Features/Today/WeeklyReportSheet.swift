import SwiftUI

struct WeeklyReportSheet: View {
    let weekTitle: String
    let todos: [TodoItem]
    let projects: [Project]

    @Environment(\.dismiss) private var dismiss

    @State private var reportText: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if isLoading {
                        VStack(spacing: 12) {
                            ProgressView()
                                .controlSize(.regular)
                            Text("正在生成周报...")
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 200)
                    } else if let error = errorMessage {
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 40))
                                .foregroundStyle(.orange)
                            Text("生成失败")
                                .appFont(.headline)
                            Text(error)
                                .appFont(.callout)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, minHeight: 200)
                        .padding(.horizontal, 24)
                    } else if !reportText.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text(weekTitle)
                                    .appFont(.title3, design: .rounded, weight: .bold)
                                Spacer()
                                Button(action: copyToClipboard) {
                                    Image(systemName: "doc.on.doc")
                                        .appFont(.body)
                                }
                                .buttonStyle(.borderless)
                            }

                            Text(reportText)
                                .appFont(.body)
                                .lineSpacing(4)
                                .textSelection(.enabled)
                        }
                        .padding(16)
                        .background(Color(.tertiarySystemFill))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .navigationTitle("周报")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 400, minHeight: 300)
        .task {
            await generateReport()
        }
    }

    private func generateReport() async {
        let config = TodoStore.shared.llmConfig
        guard !config.apiKey.isEmpty else {
            errorMessage = "请先在设置中配置 LLM API"
            return
        }

        isLoading = true
        defer { isLoading = false }

        let prompt = buildPrompt()
        let messages = [
            LLMChatMessage(role: "system", content: "你是一位专业的职场助理，擅长根据任务列表生成简洁、专业的工作周报。使用中文。"),
            LLMChatMessage(role: "user", content: prompt)
        ]

        do {
            reportText = try await LLMService.shared.chat(messages: messages, config: config)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func buildPrompt() -> String {
        let template = TodoStore.shared.llmConfig.reportTemplate
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let requirements = template.isEmpty ? LLMConfig.defaultReportTemplate : template

        var lines: [String] = []
        lines.append("请根据以下本周完成的任务，生成一份工作周报。")
        lines.append("")
        lines.append("要求：")
        lines.append(requirements)
        lines.append("")
        lines.append("本周完成的任务列表：")
        lines.append("")

        for todo in todos {
            let projectName = projectName(for: todo.projectId)
            let dateStr = formattedDate(todo.completedAt)
            lines.append("- \(todo.title)\(projectName.isEmpty ? "" : "（项目：\(projectName)）")\(dateStr.isEmpty ? "" : " — \(dateStr)")")
            if !todo.description.isEmpty {
                lines.append("  备注：\(todo.description)")
            }
        }

        return lines.joined(separator: "\n")
    }

    private func projectName(for projectId: String?) -> String {
        guard let id = projectId else { return "" }
        return projects.first { $0.id == id }?.name ?? ""
    }

    private func formattedDate(_ date: Date?) -> String {
        guard let date = date else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日"
        return formatter.string(from: date)
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
