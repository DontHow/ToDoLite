import SwiftUI

extension CreateTodoView {
    var modeToggle: some View {
        modeToggleContent
            .padding(.top, 16)
            .padding(.bottom, 20)
    }

    var inlineModeToggle: some View {
        modeToggleContent
    }

    var modeToggleContent: some View {
        HStack(spacing: 0) {
            modeButton("快速输入", icon: "bolt.fill", isActive: useQuickEntry) {
                useQuickEntry = true
            }
            modeButton("详细输入", icon: "slider.horizontal.3", isActive: !useQuickEntry) {
                useQuickEntry = false
            }
        }
        .background(Color.chipBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    func modeButton(_ label: String, icon: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .appFont(.subheadline)
                Text(label)
                    .appFont(.subheadline, weight: isActive ? .semibold : .regular)
            }
            .foregroundStyle(isActive ? .white : .primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isActive ? Color.accentColor : Color.clear)
            .contentShape(Rectangle())
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}
