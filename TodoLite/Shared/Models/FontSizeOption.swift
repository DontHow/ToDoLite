import SwiftUI

enum FontSizeOption: Int, CaseIterable, Identifiable {
    case extraSmall = -2
    case small = -1
    case standard = 0
    case large = 1
    case extraLarge = 2
    case xxLarge = 3
    case xxxLarge = 4

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .extraSmall: return "极小"
        case .small: return "小"
        case .standard: return "标准"
        case .large: return "大"
        case .extraLarge: return "极大"
        case .xxLarge: return "超大"
        case .xxxLarge: return "最大"
        }
    }

    var dynamicTypeSize: DynamicTypeSize {
        #if os(macOS)
        switch self {
        case .extraSmall: return .xSmall
        case .small: return .small
        case .standard: return .medium
        case .large: return .xLarge
        case .extraLarge: return .xxLarge
        case .xxLarge: return .xxxLarge
        case .xxxLarge: return .accessibility3
        }
        #else
        switch self {
        case .extraSmall: return .xSmall
        case .small: return .small
        case .standard: return .medium
        case .large: return .large
        case .extraLarge: return .xLarge
        case .xxLarge: return .xxLarge
        case .xxxLarge: return .xxxLarge
        }
        #endif
    }

    var scale: CGFloat {
        switch self {
        case .extraSmall: return 0.82
        case .small: return 0.90
        case .standard: return 1.0
        case .large: return 1.10
        case .extraLarge: return 1.20
        case .xxLarge: return 1.32
        case .xxxLarge: return 1.45
        }
    }

    init?(level: Int) {
        guard let option = FontSizeOption(rawValue: level) else { return nil }
        self = option
    }
}
