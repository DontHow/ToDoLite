import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    settingsSection(title: "项目") {
                        NavigationLink(destination: ProjectListView()) {
                            settingsRow(icon: "folder", iconColor: .blue, label: "管理项目")
                        }
                        .buttonStyle(CardButtonStyle())
                    }

                    settingsSection(title: "标签") {
                        NavigationLink(destination: TagListView()) {
                            settingsRow(icon: "number", iconColor: .purple, label: "管理标签")
                        }
                        .buttonStyle(CardButtonStyle())
                    }

                    settingsSection(title: "AI") {
                        NavigationLink(destination: LLMConfigView()) {
                            settingsRow(icon: "cpu", iconColor: .indigo, label: "LLM 配置")
                        }
                        .buttonStyle(CardButtonStyle())
                    }

                    settingsSection(title: "历史") {
                        NavigationLink(destination: DoneView()) {
                            settingsRow(icon: "checkmark.circle", iconColor: .green, label: "已完成")
                        }
                        .buttonStyle(CardButtonStyle())

                        NavigationLink(destination: ArchiveView()) {
                            settingsRow(icon: "archivebox", iconColor: .orange, label: "已归档")
                        }
                        .buttonStyle(CardButtonStyle())
                    }

                    settingsSection(title: "关于") {
                        HStack {
                            Text("版本")
                            Spacer()
                            Text("1.0.0")
                                .foregroundStyle(Color.labelSecondary)
                        }
                        .padding(16)
                        .background(Color.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, 12)
            }
            .navigationTitle("设置")
        }
    }

    private func settingsSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .padding(.horizontal, 4)
            VStack(spacing: 8) {
                content()
            }
        }
    }

    private func settingsRow(icon: String, iconColor: Color, label: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(iconColor)
                .symbolRenderingMode(.hierarchical)
            Text(label)
                .font(.callout.weight(.medium))
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(Color.labelSecondary)
        }
        .padding(16)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .contentShape(Rectangle())
    }

    private var horizontalPadding: CGFloat {
        #if os(iOS)
        16
        #else
        12
        #endif
    }
}
