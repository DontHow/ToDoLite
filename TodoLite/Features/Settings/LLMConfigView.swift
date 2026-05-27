import SwiftUI

struct LLMConfigView: View {
    @State private var apiKey: String = ""
    @State private var baseURL: String = ""
    @State private var model: String = ""
    @State private var isSaving = false

    var body: some View {
        Form {
            Section("API 设置") {
                TextField("Base URL", text: $baseURL)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                    .autocorrectionDisabled()
                SecureField("API Key", text: $apiKey)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                    .autocorrectionDisabled()
            }

            Section("模型") {
                TextField("Model", text: $model)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                    .autocorrectionDisabled()
            }

            Section {
                Button(action: save) {
                    HStack {
                        Spacer()
                        if isSaving {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("保存")
                        }
                        Spacer()
                    }
                }
                .disabled(isSaving || !isValid)
            }
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
}
