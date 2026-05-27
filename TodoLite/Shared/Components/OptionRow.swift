import SwiftUI

struct OptionRow<Content: View>: View {
    let icon: String
    let iconColor: Color
    let label: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .foregroundStyle(iconColor)
                    .font(.body)
                    .symbolRenderingMode(.hierarchical)
                Text(label)
                    .font(.callout.weight(.medium))
                Spacer()
            }
            content
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.cardBackground)
        )
    }
}
