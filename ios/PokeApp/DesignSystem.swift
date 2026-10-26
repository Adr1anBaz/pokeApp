import SwiftUI
import UIKit

enum DSColor {
    static let red = Color(hex: 0xE3350D)
    static let blue = Color(hex: 0x3B6FD8)
    static let yellow = Color(hex: 0xFFCB05)
    static let ink = Color(hex: 0x283038)
    static let paper = Color(hex: 0xF8F8F8)
    static let mist = Color(hex: 0xE9F1FA)
    static let mutedInk = Color(hex: 0x5A6570)

    static let hpHigh = Color(hex: 0x38D058)
    static let hpMedium = Color(hex: 0xF8C800)
    static let hpLow = Color(hex: 0xF03030)

    static let skyTop = Color(hex: 0x7FD8F0)
    static let skyBottom = Color(hex: 0xD8F8E0)
    static let grass = Color(hex: 0x78C850)
    static let grassDark = Color(hex: 0x4E9A32)

    static func hp(for ratio: Double) -> Color {
        ratio > 0.5 ? hpHigh : ratio > 0.2 ? hpMedium : hpLow
    }

    static func type(_ identifier: String) -> Color {
        typeColors[identifier.lowercased()] ?? ink
    }

    private static let typeColors: [String: Color] = [
        "normal": Color(hex: 0xA8A878), "fire": Color(hex: 0xF08030),
        "water": Color(hex: 0x6890F0), "electric": Color(hex: 0xF8D030),
        "grass": Color(hex: 0x78C850), "ice": Color(hex: 0x98D8D8),
        "fighting": Color(hex: 0xC03028), "poison": Color(hex: 0xA040A0),
        "ground": Color(hex: 0xE0C068), "flying": Color(hex: 0xA890F0),
        "psychic": Color(hex: 0xF85888), "bug": Color(hex: 0xA8B820),
        "rock": Color(hex: 0xB8A038), "ghost": Color(hex: 0x705898),
        "dragon": Color(hex: 0x7038F8), "dark": Color(hex: 0x705848),
        "steel": Color(hex: 0xB8B8D0), "fairy": Color(hex: 0xEE99AC)
    ]
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

enum DSFont {
    private static let titleName = "PressStart2P-Regular"
    private static let bodyName = "PixelifySans-Regular"

    static func title(_ size: CGFloat) -> Font {
        UIFont(name: titleName, size: size) == nil ? .system(size: size, weight: .bold, design: .monospaced) : .custom(titleName, size: size)
    }

    static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        UIFont(name: bodyName, size: size) == nil ? .system(size: size, weight: weight, design: .monospaced) : .custom(bodyName, size: size).weight(weight)
    }
}

enum DSButtonTone {
    case primary, secondary, danger

    fileprivate var color: Color {
        switch self {
        case .primary: DSColor.blue
        case .secondary: DSColor.red
        case .danger: DSColor.ink
        }
    }
}

struct DSButton<Label: View>: View {
    let tone: DSButtonTone
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    init(tone: DSButtonTone = .primary, action: @escaping () -> Void, @ViewBuilder label: @escaping () -> Label) {
        self.tone = tone
        self.action = action
        self.label = label
    }

    var body: some View {
        Button(action: action, label: label)
            .buttonStyle(DSButtonStyle(tone: tone))
    }
}

struct DSButtonStyle: ButtonStyle {
    let tone: DSButtonTone

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DSFont.body(16, weight: .bold))
            .foregroundStyle(DSColor.paper)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 18)
            .background(tone.color, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(DSColor.ink, lineWidth: 3)
            }
            .shadow(color: DSColor.ink, radius: 0, x: 0, y: configuration.isPressed ? 1 : 4)
            .offset(y: configuration.isPressed ? 3 : 0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

struct DSPanel<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .background(DSColor.paper, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(DSColor.ink, lineWidth: 3)
            }
            .shadow(color: DSColor.ink.opacity(0.25), radius: 0, x: 0, y: 3)
    }
}

struct DSInput: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var alignment: TextAlignment = .leading
    var fill: Color = DSColor.mist

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(DSFont.body(11, weight: .bold))
                .foregroundStyle(DSColor.mutedInk)
            TextField(placeholder, text: $text)
                .font(DSFont.body(17, weight: .bold))
                .foregroundStyle(DSColor.ink)
                .multilineTextAlignment(alignment)
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .background(fill, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(DSColor.ink, lineWidth: 2)
                }
        }
    }
}

struct DSSectionTitle: View {
    let title: String
    let subtitle: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(DSFont.title(12))
                .foregroundStyle(color)
            Text(subtitle)
                .font(DSFont.body(14))
                .foregroundStyle(DSColor.ink)
        }
    }
}

struct DSDialogueBox: View {
    let text: String
    var speaker: String? = nil

    var body: some View {
        DSPanel {
            VStack(alignment: .leading, spacing: 8) {
                if let speaker {
                    Text(speaker)
                        .font(DSFont.title(10))
                        .foregroundStyle(DSColor.blue)
                }
                Text(text)
                    .font(DSFont.body(18))
                    .foregroundStyle(DSColor.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
