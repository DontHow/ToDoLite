import SwiftUI

#if os(macOS)
import AppKit
#endif

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

private struct AppFontScaleKey: EnvironmentKey {
    static let defaultValue: CGFloat = 1
}

private extension EnvironmentValues {
    var appFontScale: CGFloat {
        get { self[AppFontScaleKey.self] }
        set { self[AppFontScaleKey.self] = newValue }
    }
}

private struct AppFontModifier: ViewModifier {
    @Environment(\.appFontScale) private var scale

    let style: Font.TextStyle
    let design: Font.Design
    let weight: Font.Weight?

    func body(content: Content) -> some View {
        #if os(macOS)
        content.font(
            .system(
                size: style.macOSPointSize * scale,
                weight: weight ?? style.macOSDefaultWeight,
                design: design
            )
        )
        #else
        content.font(.system(style, design: design, weight: weight))
        #endif
    }
}

private struct AppFontScaleModifier: ViewModifier {
    let scale: CGFloat

    func body(content: Content) -> some View {
        #if os(macOS)
        content
            .environment(\.appFontScale, scale)
            .font(.system(size: Font.TextStyle.body.macOSPointSize * scale))
        #else
        content.environment(\.appFontScale, scale)
        #endif
    }
}

extension View {
    func appFont(
        _ style: Font.TextStyle,
        design: Font.Design = .default,
        weight: Font.Weight? = nil
    ) -> some View {
        modifier(AppFontModifier(style: style, design: design, weight: weight))
    }

    func appFontScale(_ scale: CGFloat) -> some View {
        modifier(AppFontScaleModifier(scale: scale))
    }
}

#if os(macOS)
private extension Font.TextStyle {
    var macOSPointSize: CGFloat {
        NSFont.preferredFont(forTextStyle: macOSTextStyle).pointSize
    }

    var macOSDefaultWeight: Font.Weight {
        self == .headline ? .semibold : .regular
    }

    var macOSTextStyle: NSFont.TextStyle {
        if self == .largeTitle { return .largeTitle }
        if self == .title { return .title1 }
        if self == .title2 { return .title2 }
        if self == .title3 { return .title3 }
        if self == .headline { return .headline }
        if self == .subheadline { return .subheadline }
        if self == .callout { return .callout }
        if self == .footnote { return .footnote }
        if self == .caption { return .caption1 }
        if self == .caption2 { return .caption2 }
        return .body
    }
}
#endif
