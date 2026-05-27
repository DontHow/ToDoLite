import SwiftUI

struct LLMConfigView: View {
    @State private var apiKey: String = ""
    @State private var baseURL: String = ""
    @State private var model: String = ""
    @State private var isSaving = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "server.rack")
                            .foregroundStyle(.blue)
                            .font(.body)
                            .symbolRenderingMode(.hierarchical)
                        Text("API 设置")
                            .font(.system(.title3, design: .rounded, weight: .bold))
                        Spacer()
                    }

                    VStack(spacing: 12) {
                        TextField("Base URL", text: $baseURL)
                            #if os(iOS)
                            .textInputAutocapitalization(.never)
                            #endif
                            .autocorrectionDisabled()

                        Divider()

                        SecureField("API Key", text: $apiKey)
                            #if os(iOS)
                            .textInputAutocapitalization(.never)
                            #endif
                            .autocorrectionDisabled()
                    }
                }
                .padding(18)
                .background(Color.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 18))

                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "cube")
                            .foregroundStyle(.purple)
                            .font(.body)
                            .symbolRenderingMode(.hierarchical)
                        Text("模型")
                            .font(.system(.title3, design: .rounded, weight: .bold))
                        Spacer()
                    }

                    TextField("Model", text: $model)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                        .autocorrectionDisabled()
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
                        } else {
                            Text("保存")
                                .font(.headline)
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
        .task {
            let config = TodoStore.shared.llmConfig
            apiKey = config.apiKey
            baseURL = config.baseURL
            model = config.model
        }
    }

    private var isValid: Bool {
        !baseURL.isEmpty && !model.isEmpty
    }

    private func save() {
        isSaving = true
        let config = LLMConfig(apiKey: apiKey, baseURL: baseURL, model: model)
        Task {
            do {
                try await TodoStore.shared.saveLLMConfig(config)
            } catch {
                // TODO: show error
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
