import SwiftUI

// shortcut: CLT has no SwiftUIMacros, so @State will not compile. Use @State once Xcode is installed.
final class Hold<Value>: ObservableObject {
    @Published var value: Value
    init(_ value: Value) { self.value = value }
}

enum Theme {
    static let primary = Color(red: 79 / 255, green: 70 / 255, blue: 229 / 255)
    static let primaryPressed = Color(red: 67 / 255, green: 56 / 255, blue: 202 / 255)
    static let primaryLight = Color(red: 238 / 255, green: 242 / 255, blue: 255 / 255)
    static let success = Color(red: 16 / 255, green: 185 / 255, blue: 129 / 255)
    static let successBg = Color(red: 236 / 255, green: 253 / 255, blue: 245 / 255)
    static let warning = Color(red: 245 / 255, green: 158 / 255, blue: 11 / 255)
    static let warningBg = Color(red: 255 / 255, green: 251 / 255, blue: 235 / 255)
    static let danger = Color(red: 239 / 255, green: 68 / 255, blue: 68 / 255)
    static let dangerBg = Color(red: 254 / 255, green: 242 / 255, blue: 242 / 255)
    static let bg = Color(red: 247 / 255, green: 248 / 255, blue: 252 / 255)
    static let text = Color(red: 17 / 255, green: 24 / 255, blue: 39 / 255)
    static let secondary = Color(red: 107 / 255, green: 114 / 255, blue: 128 / 255)
    static let border = Color(red: 229 / 255, green: 231 / 255, blue: 235 / 255)
    static let remoteBg = Color(red: 239 / 255, green: 246 / 255, blue: 255 / 255)
    static let remoteFg = Color(red: 37 / 255, green: 99 / 255, blue: 235 / 255)
    static let cardRadius: CGFloat = 12
    static let controlRadius: CGFloat = 8
}

struct PrimaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(configuration.isPressed ? Theme.primaryPressed : Theme.primary)
            .clipShape(RoundedRectangle(cornerRadius: Theme.controlRadius))
    }
}

struct QuietButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Theme.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(Theme.primaryLight.opacity(configuration.isPressed ? 0.7 : 1))
            .clipShape(RoundedRectangle(cornerRadius: Theme.controlRadius))
    }
}

struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
            .overlay(RoundedRectangle(cornerRadius: Theme.cardRadius).stroke(Theme.border))
            .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
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
            (Theme.primaryLight, Theme.primary),
            (Theme.remoteBg, Theme.remoteFg),
            (Theme.successBg, Theme.success),
            (Color(red: 1, green: 0.95, blue: 0.9), Color(red: 0.85, green: 0.47, blue: 0.02)),
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
