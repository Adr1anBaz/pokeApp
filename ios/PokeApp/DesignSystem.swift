import SwiftUI
import UIKit

// Port of android/.../ui/theme (Theme.kt, Types.kt) and ui/components/Components.kt.

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

/// DS-era palette.
enum Ds {
    static let ink = Color(hex: 0x283038)
    static let inkSoft = Color(hex: 0x5A6470)
    static let paper = Color(hex: 0xF8F8F8)
    static let frame = Color(hex: 0x4A5560)
    static let red = Color(hex: 0xE3350D)
    static let redDark = Color(hex: 0x9E2A0C)
    static let blue = Color(hex: 0x3B6FD8)
    static let blueDark = Color(hex: 0x22408A)
    static let yellow = Color(hex: 0xFFCB05)
    static let yellowDark = Color(hex: 0xC79A00)
    static let green = Color(hex: 0x3FA34D)
    static let greenDark = Color(hex: 0x256B30)
    static let hpGreen = Color(hex: 0x38D058)
    static let hpYellow = Color(hex: 0xF8C800)
    static let hpRed = Color(hex: 0xF03030)
    static let skyTop = Color(hex: 0x7FD8F0)
    static let skyBottom = Color(hex: 0xD8F8E0)
    static let grass = Color(hex: 0x78C850)
    static let grassDark = Color(hex: 0x4E9A32)
}

/// Pixel fonts registered by RemoteFontLoader; monospace until they arrive.
enum PixelFont {
    static let titleName = "PressStart2P-Regular"
    static let bodyName = "PixelifySans-Regular"

    static func title(_ size: CGFloat) -> Font {
        UIFont(name: titleName, size: size) == nil ? .system(size: size * 0.85, weight: .black, design: .monospaced) : .custom(titleName, size: size)
    }

    static func body(_ size: CGFloat, bold: Bool = false) -> Font {
        let font: Font = UIFont(name: bodyName, size: size) == nil ? .system(size: size, design: .monospaced) : .custom(bodyName, size: size)
        return bold ? font.bold() : font
    }

    // Same scale as the Android typography (sp ≈ pt).
    static var display: Font { title(30) }
    static var headlineLarge: Font { title(22) }
    static var headlineMedium: Font { title(18) }
    static var headlineSmall: Font { title(14) }
    static var titleLarge: Font { body(24) }
    static var titleMedium: Font { body(20) }
    static var titleSmall: Font { body(17) }
    static var bodyLarge: Font { body(20) }
    static var bodyMedium: Font { body(17) }
    static var bodySmall: Font { body(14) }
    static var labelLarge: Font { body(18) }
    static var labelMedium: Font { body(15) }
    static var labelSmall: Font { body(12) }
}

/// Visual info per Pokémon type: card/badge color and Spanish name.
struct TypeStyle {
    let color: Color
    let dark: Color
    let es: String
}

enum PokeTypes {
    private static let styles: [String: TypeStyle] = [
        "normal": TypeStyle(color: Color(hex: 0xA8A878), dark: Color(hex: 0x6D6D4E), es: "Normal"),
        "fire": TypeStyle(color: Color(hex: 0xF08030), dark: Color(hex: 0x9C531F), es: "Fuego"),
        "water": TypeStyle(color: Color(hex: 0x6890F0), dark: Color(hex: 0x445E9C), es: "Agua"),
        "electric": TypeStyle(color: Color(hex: 0xF8D030), dark: Color(hex: 0xA1871F), es: "Eléctrico"),
        "grass": TypeStyle(color: Color(hex: 0x78C850), dark: Color(hex: 0x4E8234), es: "Planta"),
        "ice": TypeStyle(color: Color(hex: 0x98D8D8), dark: Color(hex: 0x638D8D), es: "Hielo"),
        "fighting": TypeStyle(color: Color(hex: 0xC03028), dark: Color(hex: 0x7D1F1A), es: "Lucha"),
        "poison": TypeStyle(color: Color(hex: 0xA040A0), dark: Color(hex: 0x682A68), es: "Veneno"),
        "ground": TypeStyle(color: Color(hex: 0xE0C068), dark: Color(hex: 0x927D44), es: "Tierra"),
        "flying": TypeStyle(color: Color(hex: 0xA890F0), dark: Color(hex: 0x6D5E9C), es: "Volador"),
        "psychic": TypeStyle(color: Color(hex: 0xF85888), dark: Color(hex: 0xA13959), es: "Psíquico"),
        "bug": TypeStyle(color: Color(hex: 0xA8B820), dark: Color(hex: 0x6D7815), es: "Bicho"),
        "rock": TypeStyle(color: Color(hex: 0xB8A038), dark: Color(hex: 0x786824), es: "Roca"),
        "ghost": TypeStyle(color: Color(hex: 0x705898), dark: Color(hex: 0x493963), es: "Fantasma"),
        "dragon": TypeStyle(color: Color(hex: 0x7038F8), dark: Color(hex: 0x4924A1), es: "Dragón"),
        "dark": TypeStyle(color: Color(hex: 0x705848), dark: Color(hex: 0x49392F), es: "Siniestro"),
        "steel": TypeStyle(color: Color(hex: 0xB8B8D0), dark: Color(hex: 0x787887), es: "Acero"),
        "fairy": TypeStyle(color: Color(hex: 0xEE99AC), dark: Color(hex: 0x9B6470), es: "Hada"),
    ]

    static func style(_ type: String?) -> TypeStyle { styles[type ?? ""] ?? styles["normal"]! }

    /// Mirrors calculateDamage() in pokemon-server/server.js (its small chart, defender's first type),
    /// so the "super effective" text matches the damage the server really applied.
    private static let serverChart: [String: [String: Double]] = [
        "fire": ["grass": 2, "water": 0.5, "fire": 0.5],
        "water": ["fire": 2, "grass": 0.5, "water": 0.5],
        "grass": ["water": 2, "fire": 0.5, "grass": 0.5],
        "electric": ["water": 2, "grass": 0.5, "electric": 0.5],
    ]

    static func serverEffectiveness(_ moveType: String?, _ defenderTypes: [String]?) -> Double {
        guard let moveType, let first = defenderTypes?.first else { return 1 }
        return serverChart[moveType]?[first] ?? 1
    }
}

/// Sprite URLs served by PokeAPI's sprites repo (nothing is bundled in the project).
enum Sprites {
    private static let base = "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon"
    static func animatedFront(_ id: Int) -> String { "\(base)/other/showdown/\(id).gif" }
    static func animatedBack(_ id: Int) -> String { "\(base)/other/showdown/back/\(id).gif" }
    static func front(_ id: Int) -> String { "\(base)/\(id).png" }
    static func back(_ id: Int) -> String { "\(base)/back/\(id).png" }
    static func artwork(_ id: Int) -> String { "\(base)/other/official-artwork/\(id).png" }

    private static let typeIds = [
        "normal", "fighting", "flying", "poison", "ground", "rock", "bug", "ghost", "steel",
        "fire", "water", "grass", "electric", "psychic", "ice", "dragon", "dark", "fairy",
    ]

    /// Official Scarlet/Violet type symbol (no text), 60x60.
    static func typeIcon(_ type: String?) -> String {
        let id = (typeIds.firstIndex(of: type ?? "") ?? 0) + 1
        return "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/types/generation-ix/scarlet-violet/small/\(id).png"
    }
}

// MARK: - Components

/// Animated diagonal stripes, like the DS menus' backdrops. Clipped so they never reach the status bar.
struct StripedBackground<Content: View>: View {
    var top: Color
    var bottom: Color
    let content: Content

    init(top: Color = Color(hex: 0xE85040), bottom: Color = Color(hex: 0xF8A040), @ViewBuilder content: () -> Content) {
        self.top = top
        self.bottom = bottom
        self.content = content()
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .bottom)
            TimelineView(.animation) { context in
                Canvas { g, size in
                    let gap: CGFloat = 48
                    let shift = CGFloat(context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 6) / 6)
                    var x = -size.height + shift * gap * 2 - gap * 2
                    while x < size.width + gap {
                        var line = Path()
                        line.move(to: CGPoint(x: x, y: size.height))
                        line.addLine(to: CGPoint(x: x + size.height, y: 0))
                        g.stroke(line, with: .color(.white.opacity(0.10)), lineWidth: gap * 0.45)
                        x += gap
                    }
                }
            }
            content
        }
        .clipped()
    }
}

/// White dialog panel with the double frame DS games use.
struct DsPanel<Content: View>: View {
    var accent: Color = Ds.blue
    var padding: CGFloat = 14
    let content: Content

    init(accent: Color = Ds.blue, padding: CGFloat = 14, @ViewBuilder content: () -> Content) {
        self.accent = accent
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(RoundedRectangle(cornerRadius: 9).fill(Ds.paper))
            .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(accent, lineWidth: 3))
            .padding(6)
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Ds.frame, lineWidth: 3))
    }
}

/// Chunky button with a bottom "3D" edge that sinks when pressed.
struct PixelButton: View {
    let text: String
    var color: Color = Ds.red
    var dark: Color = Ds.redDark
    var enabled: Bool = true
    var sfx: Sfx = .select
    var font: Font = PixelFont.headlineSmall
    var fullWidth: Bool = true
    let action: () -> Void

    var body: some View {
        Button {
            Sound.shared.play(sfx)
            action()
        } label: {
            Text(text)
        }
        .buttonStyle(PixelButtonStyle(
            face: enabled ? color : Color(hex: 0xB8B8B8),
            edge: enabled ? dark : Color(hex: 0x888888),
            font: font,
            fullWidth: fullWidth,
            enabled: enabled
        ))
        .disabled(!enabled)
    }
}

struct PixelButtonStyle: ButtonStyle {
    let face: Color
    let edge: Color
    let font: Font
    let fullWidth: Bool
    let enabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        let depth: CGFloat = configuration.isPressed && enabled ? 1 : 5
        let shape = RoundedRectangle(cornerRadius: 12)
        return configuration.label
            .font(font)
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(LinearGradient(colors: [face.opacity(0.85), face], startPoint: .top, endPoint: .bottom))
            .overlay(shape.strokeBorder(Color.white.opacity(0.35), lineWidth: 2))
            .clipShape(shape)
            .padding(.bottom, depth)
            .background(shape.fill(edge))
            .padding(.top, 5 - depth)
    }
}

/// Text with a thick outline, used for the logo and big headings.
struct OutlinedText: View {
    let text: String
    let font: Font
    var fill: Color = Ds.yellow
    var outline: Color = Ds.blueDark
    var width: CGFloat = 3

    var body: some View {
        ZStack {
            ForEach(0..<16, id: \.self) { i in
                let angle = Double(i) / 16 * 2 * Double.pi
                Text(text)
                    .font(font)
                    .foregroundColor(outline)
                    .offset(x: CGFloat(cos(angle)) * width, y: CGFloat(sin(angle)) * width)
            }
            Text(text).font(font).foregroundColor(fill)
        }
        .multilineTextAlignment(.center)
    }
}

/// A Poké Ball drawn in code so it can spin, grey out or flash.
struct Pokeball: View {
    var size: CGFloat = 24
    var greyed: Bool = false
    var rotation: Double = 0

    var body: some View {
        Canvas { g, canvasSize in
            Pokeball.draw(in: g, center: CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2),
                          radius: min(canvasSize.width, canvasSize.height) / 2, greyed: greyed)
        }
        .frame(width: size, height: size)
        .rotationEffect(.degrees(rotation))
    }

    static func draw(in g: GraphicsContext, center c: CGPoint, radius r: CGFloat, greyed: Bool = false) {
        let top = greyed ? Color(hex: 0x9A9A9A) : Ds.red
        let line = r * 0.16
        let circle = Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
        g.fill(circle, with: .color(.white))
        var upper = g
        upper.clip(to: Path(CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: r)))
        upper.fill(circle, with: .color(top))
        g.stroke(Path(ellipseIn: CGRect(x: c.x - r + line / 2, y: c.y - r + line / 2, width: 2 * r - line, height: 2 * r - line)),
                 with: .color(Ds.ink), lineWidth: line)
        var bar = Path()
        bar.move(to: CGPoint(x: c.x - r, y: c.y))
        bar.addLine(to: CGPoint(x: c.x + r, y: c.y))
        g.stroke(bar, with: .color(Ds.ink), lineWidth: line)
        g.fill(Path(ellipseIn: CGRect(x: c.x - r * 0.36, y: c.y - r * 0.36, width: r * 0.72, height: r * 0.72)), with: .color(Ds.ink))
        g.fill(Path(ellipseIn: CGRect(x: c.x - r * 0.22, y: c.y - r * 0.22, width: r * 0.44, height: r * 0.44)), with: .color(.white))
    }
}

struct SpinningPokeball: View {
    var size: CGFloat = 28

    var body: some View {
        TimelineView(.animation) { context in
            let angle = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 0.9) / 0.9 * 360
            Pokeball(size: size, rotation: angle)
        }
    }
}

/// DS HP bar. [hp] is a Double so it can be animated smoothly as damage drains it.
struct HpBar: View {
    let hp: Double
    let maxHp: Int

    var body: some View {
        let fraction = maxHp > 0 ? min(max(hp / Double(maxHp), 0), 1) : 0
        let color = fraction > 0.5 ? Ds.hpGreen : fraction > 0.2 ? Ds.hpYellow : Ds.hpRed
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4).fill(Color(hex: 0x506058))
                RoundedRectangle(cornerRadius: 4)
                    .fill(LinearGradient(colors: [color.opacity(0.75), color, color], startPoint: .top, endPoint: .bottom))
                    .frame(width: proxy.size.width * fraction)
            }
        }
        .padding(2)
        .background(RoundedRectangle(cornerRadius: 6).fill(Ds.ink))
        .frame(height: 12)
    }
}

/// Remote image (artwork, type symbols); empty while loading.
struct RemoteImage: View {
    let url: String

    var body: some View {
        AsyncImage(url: URL(string: url)) { image in
            image.resizable().scaledToFit()
        } placeholder: {
            Color.clear
        }
    }
}

struct TypeBadge: View {
    let type: String
    var font: Font = PixelFont.labelSmall

    var body: some View {
        let s = PokeTypes.style(type)
        HStack(spacing: 3) {
            RemoteImage(url: Sprites.typeIcon(type))
                .frame(width: 14, height: 14)
                .clipShape(RoundedRectangle(cornerRadius: 3))
            Text(s.es.uppercased())
                .font(font)
                .foregroundColor(.white)
                .lineLimit(1)
                .fixedSize()
        }
        .padding(.leading, 2)
        .padding(.trailing, 6)
        .padding(.vertical, 1)
        .background(RoundedRectangle(cornerRadius: 6).fill(s.color))
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(s.dark, lineWidth: 1.5))
    }
}

struct ErrorBanner: View {
    let message: String?

    var body: some View {
        if let message {
            Text(message)
                .font(PixelFont.bodyMedium)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 10).fill(Ds.redDark.opacity(0.92)))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.white.opacity(0.5), lineWidth: 2))
        }
    }
}

/// Text field with its label on top, in the DS style.
struct DsTextField: View {
    let label: String
    @Binding var text: String
    var placeholder: String = ""
    var keyboard: UIKeyboardType = .default
    var capitalization: TextInputAutocapitalization = .words
    var font: Font = PixelFont.titleMedium

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(PixelFont.labelSmall)
                .foregroundColor(Ds.inkSoft)
            TextField(placeholder, text: $text)
                .font(font)
                .foregroundColor(Ds.ink)
                .keyboardType(keyboard)
                .textInputAutocapitalization(capitalization)
                .autocorrectionDisabled()
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.white))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Ds.frame, lineWidth: 2))
        }
    }
}
