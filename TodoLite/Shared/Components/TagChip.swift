import SwiftUI

struct TagChip: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .appFont(.caption2)
            Text(text)
                .appFont(.caption, weight: .medium)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.9))
        .clipShape(Capsule())
    }
}
