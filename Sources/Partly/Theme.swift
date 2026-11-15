import AppKit
import SwiftUI

// shortcut: CLT has no SwiftUIMacros, so @State will not compile. Use @State once Xcode is installed.
final class Hold<Value>: ObservableObject {
    @Published var value: Value
    init(_ value: Value) { self.value = value }
}

struct Theme: Equatable {
    let dark: Bool
    let primary: Color
    let primaryPressed: Color
    let primaryLight: Color
    let onPrimary: Color
    let success: Color
    let successBg: Color
    let warning: Color
    let warningBg: Color
    let warningFg: Color
    let danger: Color
    let dangerBg: Color
    let bg: Color
    let surface: Color
    let text: Color
    let secondary: Color
    let border: Color
    let remoteBg: Color
    let remoteFg: Color

    var scheme: ColorScheme { dark ? .dark : .light }

    static let cardRadius: CGFloat = 12
    static let controlRadius: CGFloat = 8

    static let light = Theme(
        dark: false,
        primary: Color(red: 79 / 255, green: 70 / 255, blue: 229 / 255),
        primaryPressed: Color(red: 67 / 255, green: 56 / 255, blue: 202 / 255),
        primaryLight: Color(red: 238 / 255, green: 242 / 255, blue: 255 / 255),
        onPrimary: .white,
        success: Color(red: 16 / 255, green: 185 / 255, blue: 129 / 255),
        successBg: Color(red: 236 / 255, green: 253 / 255, blue: 245 / 255),
        warning: Color(red: 245 / 255, green: 158 / 255, blue: 11 / 255),
        warningBg: Color(red: 255 / 255, green: 251 / 255, blue: 235 / 255),
        warningFg: Color(red: 146 / 255, green: 64 / 255, blue: 14 / 255),
        danger: Color(red: 239 / 255, green: 68 / 255, blue: 68 / 255),
        dangerBg: Color(red: 254 / 255, green: 242 / 255, blue: 242 / 255),
        bg: Color(red: 247 / 255, green: 248 / 255, blue: 252 / 255),
        surface: .white,
        text: Color(red: 17 / 255, green: 24 / 255, blue: 39 / 255),
        secondary: Color(red: 107 / 255, green: 114 / 255, blue: 128 / 255),
        border: Color(red: 229 / 255, green: 231 / 255, blue: 235 / 255),
        remoteBg: Color(red: 239 / 255, green: 246 / 255, blue: 255 / 255),
        remoteFg: Color(red: 37 / 255, green: 99 / 255, blue: 235 / 255)
    )

    static let night = Theme(
        dark: true,
        primary: Color(red: 165 / 255, green: 180 / 255, blue: 252 / 255),
        primaryPressed: Color(red: 129 / 255, green: 140 / 255, blue: 248 / 255),
        primaryLight: Color(red: 49 / 255, green: 46 / 255, blue: 90 / 255),
        onPrimary: Color(red: 15 / 255, green: 17 / 255, blue: 28 / 255),
        success: Color(red: 52 / 255, green: 211 / 255, blue: 153 / 255),
        successBg: Color(red: 6 / 255, green: 59 / 255, blue: 46 / 255),
        warning: Color(red: 251 / 255, green: 191 / 255, blue: 36 / 255),
        warningBg: Color(red: 69 / 255, green: 45 / 255, blue: 10 / 255),
        warningFg: Color(red: 252 / 255, green: 211 / 255, blue: 77 / 255),
        danger: Color(red: 248 / 255, green: 113 / 255, blue: 113 / 255),
        dangerBg: Color(red: 69 / 255, green: 26 / 255, blue: 26 / 255),
        bg: Color(red: 15 / 255, green: 17 / 255, blue: 28 / 255),
        surface: Color(red: 28 / 255, green: 31 / 255, blue: 46 / 255),
        text: Color(red: 243 / 255, green: 244 / 255, blue: 246 / 255),
        secondary: Color(red: 156 / 255, green: 163 / 255, blue: 175 / 255),
        border: Color(red: 55 / 255, green: 60 / 255, blue: 82 / 255),
        remoteBg: Color(red: 30 / 255, green: 58 / 255, blue: 98 / 255),
        remoteFg: Color(red: 147 / 255, green: 197 / 255, blue: 253 / 255)
    )
}

private struct ThemeKey: EnvironmentKey {
    static let defaultValue = Theme.light
}

extension EnvironmentValues {
    var theme: Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

struct PrimaryButton: ButtonStyle {
    var corner: CGFloat = Theme.controlRadius
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.theme) private var theme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(theme.onPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(configuration.isPressed ? theme.primaryPressed : theme.primary)
            .clipShape(RoundedRectangle(cornerRadius: corner))
            .actionCursor(enabled: isEnabled)
    }
}

struct QuietButton: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.theme) private var theme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(theme.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(theme.primaryLight.opacity(configuration.isPressed ? 0.7 : 1))
            .clipShape(RoundedRectangle(cornerRadius: Theme.controlRadius))
            .actionCursor(enabled: isEnabled)
    }
}

struct PlainActionButton: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .actionCursor(enabled: isEnabled)
    }
}

extension View {
    /// Pointing-hand cursor while the pointer is over a control that takes an action.
    func actionCursor(enabled: Bool = true) -> some View {
        onHover { hovering in
            if hovering && enabled {
                NSCursor.pointingHand.set()
            } else if !hovering {
                NSCursor.arrow.set()
            }
        }
    }
}

struct Card<Content: View>: View {
    @Environment(\.theme) private var theme
    @ViewBuilder var content: Content

    var body: some View {
        content
            .background(theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
            .overlay(RoundedRectangle(cornerRadius: Theme.cardRadius).stroke(theme.border))
            .shadow(color: .black.opacity(theme.dark ? 0.28 : 0.04), radius: 8, y: 2)
    }
}

struct Badge: View {
    let title: String
    let fg: Color
    let bg: Color
    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(fg)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(bg)
            .clipShape(Capsule())
    }
}

struct InitialsMark: View {
    @Environment(\.theme) private var theme
    let name: String
    var size: CGFloat = 40

    var body: some View {
        Text(Self.letters(name))
            .font(.system(size: size * 0.34, weight: .bold))
            .foregroundStyle(palette.1)
            .frame(width: size, height: size)
            .background(palette.0)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.28))
    }

    private var palette: (Color, Color) {
        let pairs: [(Color, Color)] = [
            (theme.primaryLight, theme.primary),
            (theme.remoteBg, theme.remoteFg),
            (theme.successBg, theme.success),
            (
                theme.dark
                    ? Color(red: 0.45, green: 0.28, blue: 0.08)
                    : Color(red: 1, green: 0.95, blue: 0.9),
                theme.dark
                    ? Color(red: 0.99, green: 0.78, blue: 0.45)
                    : Color(red: 0.85, green: 0.47, blue: 0.02)
            ),
        ]
        var hash = 0
        for scalar in name.unicodeScalars { hash = (hash &* 31) &+ Int(scalar.value) }
        return pairs[abs(hash) % pairs.count]
    }

    static func letters(_ name: String) -> String {
        let parts = name.split(separator: " ").prefix(2)
        let text = String(parts.compactMap(\.first)).uppercased()
        return text.isEmpty ? "?" : text
    }
}

func relative(_ date: Date?) -> String {
    guard let date else { return "Not verified" }
    return date.formatted(.relative(presentation: .named))
}
