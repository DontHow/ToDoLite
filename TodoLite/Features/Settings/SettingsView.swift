import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("项目") {
                    NavigationLink("管理项目") {
                        ProjectListView()
                    }
                }

                Section("标签") {
                    NavigationLink("管理标签") {
                        TagListView()
                    }
                }

                Section("AI") {
                    NavigationLink("LLM 配置") {
                        LLMConfigView()
                    }
                }

                Section("关于") {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("设置")
        }
    }
}
