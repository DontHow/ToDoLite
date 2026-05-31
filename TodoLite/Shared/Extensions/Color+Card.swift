import SwiftUI

enum SectionTheme: Equatable {
    case today
    case upcoming
    case inbox
    case doing
    case done
    case archived
    case overdue

    var backgroundHex: String {
        switch self {
        case .today: return "#F97316"
        case .upcoming: return "#2563EB"
        case .inbox: return "#6366F1"
        case .doing: return "#0D9488"
        case .done: return "#16A34A"
        case .archived: return "#64748B"
        case .overdue: return "#EF4444"
        }
    }

    var onBackgroundHex: String { "#FFFFFF" }

    var primaryTextHex: String {
        switch self {
        case .today: return "#C2410C"
        case .upcoming: return "#1D4ED8"
        case .inbox: return "#4F46E5"
        case .doing: return "#0F766E"
        case .done: return "#15803D"
        case .archived: return "#475569"
        case .overdue: return "#B91C1C"
        }
    }

    var secondaryTextHex: String {
        switch self {
        case .today: return "#EA580C"
        case .upcoming: return "#2563EB"
        case .inbox: return "#6366F1"
        case .doing: return "#0D9488"
        case .done: return "#16A34A"
        case .archived: return "#64748B"
        case .overdue: return "#DC2626"
        }
    }

    var softBackgroundHex: String {
        switch self {
        case .today: return "#FFF7ED"
        case .upcoming: return "#EFF6FF"
        case .inbox: return "#EEF2FF"
        case .doing: return "#F0FDFA"
        case .done: return "#F0FDF4"
        case .archived: return "#F8FAFC"
        case .overdue: return "#FFEBEE"
        }
    }

    var background: Color { Color(hex: backgroundHex) }
    var onBackground: Color { Color(hex: onBackgroundHex) }
    var primaryText: Color { Color(hex: primaryTextHex) }
    var secondaryText: Color { Color(hex: secondaryTextHex) }
    var softBackground: Color { Color(hex: softBackgroundHex) }
}

extension Color {
    static var cardBackground: Color {
        #if os(iOS)
        Color(uiColor: .secondarySystemBackground)
        #else
        Color(nsColor: .controlBackgroundColor)
        #endif
    }

    static var cardBackgroundTertiary: Color {
        #if os(iOS)
        Color(uiColor: .tertiarySystemBackground)
        #else
        Color(nsColor: .windowBackgroundColor).opacity(0.5)
        #endif
    }

    static var chipBackground: Color {
        #if os(iOS)
        Color(uiColor: .tertiarySystemFill)
        #else
        Color(nsColor: .controlBackgroundColor)
        #endif
    }

    static var labelSecondary: Color {
        #if os(iOS)
        Color(uiColor: .secondaryLabel)
        #else
        Color(nsColor: .secondaryLabelColor)
        #endif
    }

    static var separatorColor: Color {
        #if os(iOS)
        Color(uiColor: .separator)
        #else
        Color(nsColor: .separatorColor)
        #endif
    }

    static var today: Color { SectionTheme.today.softBackground }
    static var overdue: Color { Color(hex: "FFEBEE") }
    static var upcoming: Color { SectionTheme.upcoming.softBackground }
}
