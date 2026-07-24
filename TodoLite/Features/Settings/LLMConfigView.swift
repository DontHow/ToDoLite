import SwiftUI

struct LLMConfigView: View {
    @State private var apiKey: String = ""
    @State private var baseURL: String = ""
    @State private var model: String = ""
    @State private var reportTemplate: String = ""
    @State private var isSaving = false
    @State private var didSave = false
    @State private var isAPIKeyVisible = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "server.rack")
                            .foregroundStyle(.blue)
                            .appFont(.body)
                            .symbolRenderingMode(.hierarchical)
                        Text("API 设置")
                            .appFont(.title3, design: .rounded, weight: .bold)
                        Spacer()
                    }

                    VStack(spacing: 12) {
                        TextField("API 地址", text: $baseURL)
                            #if os(iOS)
                            .textInputAutocapitalization(.never)
                            #endif
                            .autocorrectionDisabled()

                        Divider()

                        HStack(spacing: 8) {
                            Group {
                                if isAPIKeyVisible {
                                    TextField("API 密钥", text: $apiKey)
                                } else {
                                    SecureField("API 密钥", text: $apiKey)
                                }
                            }
                            #if os(iOS)
                            .textInputAutocapitalization(.never)
                            #endif
                            .autocorrectionDisabled()

                            Button {
                                isAPIKeyVisible.toggle()
                            } label: {
                                Image(systemName: isAPIKeyVisible ? "eye.slash" : "eye")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(isAPIKeyVisible ? "隐藏密钥" : "显示密钥")
                        }
                    }
                }
                .padding(18)
                .background(Color.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 18))

                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "cube")
                            .foregroundStyle(.purple)
                            .appFont(.body)
                            .symbolRenderingMode(.hierarchical)
                        Text("模型")
                            .appFont(.title3, design: .rounded, weight: .bold)
                        Spacer()
                    }

                    TextField("模型名称", text: $model)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                        .autocorrectionDisabled()
                }
                .padding(18)
                .background(Color.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 18))

                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "doc.text")
                            .foregroundStyle(.orange)
                            .appFont(.body)
                            .symbolRenderingMode(.hierarchical)
                        Text("周报模板")
                            .appFont(.title3, design: .rounded, weight: .bold)
                        Spacer()
                        Button("填入默认模板") {
                            reportTemplate = LLMConfig.defaultReportTemplate
                        }
                        .appFont(.caption)
                        .buttonStyle(.borderless)
                    }

                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $reportTemplate)
                            .appFont(.body)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 120)
                        if reportTemplate.isEmpty {
                            Text("自定义周报生成要求，留空使用默认模板")
                                .appFont(.body)
                                .foregroundStyle(.secondary)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                                .allowsHitTesting(false)
                        }
                    }
                }
                .padding(18)
                .background(Color.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 18))

                Button(action: save) {
                    HStack {
                        Spacer()
                        if isSaving {
                            ProgressView()
                                .controlSize(.small)
                        } else if didSave {
                            Label("已保存", systemImage: "checkmark")
                                .appFont(.headline)
                        } else {
                            Text("保存")
                                .appFont(.headline)
                        }
                        Spacer()
                    }
                    .foregroundStyle(.white)
                    .padding(.vertical, 16)
                    .background(
                        isValid ? Color.accentColor : Color.gray
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .disabled(isSaving || !isValid)
                .buttonStyle(CardButtonStyle())
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, 12)
        }
        .navigationTitle("LLM 配置")
        .alert("错误", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .task {
            let config = TodoStore.shared.llmConfig
            apiKey = config.apiKey
            baseURL = config.baseURL
            model = config.model
            reportTemplate = config.reportTemplate
        }
    }

    private var isValid: Bool {
        !baseURL.isEmpty && !model.isEmpty
    }

    private func save() {
        isSaving = true
        let config = LLMConfig(
            apiKey: apiKey.trimmingCharacters(in: .whitespacesAndNewlines),
            baseURL: baseURL.trimmingCharacters(in: .whitespacesAndNewlines),
            model: model.trimmingCharacters(in: .whitespacesAndNewlines),
            reportTemplate: reportTemplate.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        Task {
            do {
                try await TodoStore.shared.saveLLMConfig(config)
                didSave = true
                try? await Task.sleep(for: .seconds(2))
                didSave = false
            } catch {
                errorMessage = "保存失败: \(error.localizedDescription)"
            }
            isSaving = false
        }
    }

    private var horizontalPadding: CGFloat {
        #if os(iOS)
        16
        #else
        12
        #endif
    }
}
