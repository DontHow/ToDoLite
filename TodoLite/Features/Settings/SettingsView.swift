import SwiftUI

struct SettingsView: View {
    @State private var store = TodoStore.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Text("设置")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    settingsSection(title: "外观") {
                        fontSizeRow
                    }

                    settingsSection(title: "AI") {
                        NavigationLink(destination: LLMConfigView()) {
                            settingsRow(icon: "cpu", iconColor: .indigo, label: "LLM 配置")
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

    private var fontSizeRow: some View {
        HStack {
            Text("字体大小")
                .font(.body.weight(.medium))
            Spacer()
            HStack(spacing: 8) {
                Button {
                    let minLevel = FontSizeOption.allCases.map(\.rawValue).min() ?? 0
                    store.fontSizeLevel = max(minLevel, store.fontSizeLevel - 1)
                } label: {
                    Image(systemName: "minus")
                        .font(.body.weight(.semibold))
                        .frame(width: 28, height: 28)
                        .background(Color.chipBackground)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Text(FontSizeOption(level: store.fontSizeLevel)?.displayName ?? "标准")
                    .font(.body.weight(.medium))
                    .frame(minWidth: 44, alignment: .center)

                Button {
                    let maxLevel = FontSizeOption.allCases.map(\.rawValue).max() ?? 0
                    store.fontSizeLevel = min(maxLevel, store.fontSizeLevel + 1)
                } label: {
                    Image(systemName: "plus")
                        .font(.body.weight(.semibold))
                        .frame(width: 28, height: 28)
                        .background(Color.chipBackground)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
                .font(.body.weight(.medium))
            Spacer()
            Image(systemName: "chevron.right")
                .font(.callout)
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
