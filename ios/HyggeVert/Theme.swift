import SwiftUI

/// Farver og skrifter fra Aarhus ToGo-prototypen.
enum Palette {
    static let background = Color(hex: 0xF3F5F0)
    static let surface = Color.white
    static let ink = Color(hex: 0x15241B)
    static let inkSecondary = Color(hex: 0x4F5E55)
    static let moss = Color(hex: 0x2E6B45)
    static let fjord = Color(hex: 0x1D5675)
    static let mossLight = Color(hex: 0xE3EEE5)
    static let fjordLight = Color(hex: 0xE0ECF2)
    static let night = Color(hex: 0x15241B)
    static let nightHighlight = Color(hex: 0x9BD3AE)
    static let car = Color(hex: 0xB5502E)
    /// Okker til partnersteder (ikke i den oprindelige palet, kontrast 5,1:1 mod hvid).
    static let ochre = Color(hex: 0x87631A)
    /// Restauranter (7,7:1 mod hvid) og aktiviteter (6,1:1 mod hvid).
    static let plum = Color(hex: 0x7A3E6E)
    static let teal = Color(hex: 0x2B6B70)
    static let hairline = Color(hex: 0x15241B).opacity(0.08)
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

/// Bricolage Grotesque til overskrifter, DM Sans til brødtekst. Følger Dynamisk tekst via `relativeTo`.
enum Typo {
    static func display(_ size: CGFloat, _ weight: Weight = .bold, relativeTo style: Font.TextStyle = .title) -> Font {
        .custom(weight.bricolage, size: size, relativeTo: style)
    }
    static func body(_ size: CGFloat = 16, _ weight: Weight = .regular, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom(weight.dmSans, size: size, relativeTo: style)
    }

    enum Weight {
        case regular, medium, semibold, bold, heavy
        var bricolage: String {
            switch self {
            case .regular, .medium, .semibold: "BricolageGrotesque-SemiBold"
            case .bold: "BricolageGrotesque-Bold"
            case .heavy: "BricolageGrotesque-ExtraBold"
            }
        }
        var dmSans: String {
            switch self {
            case .regular: "DMSans-Regular"
            case .medium: "DMSans-Medium"
            case .semibold: "DMSans-SemiBold"
            case .bold, .heavy: "DMSans-Bold"
            }
        }
    }
}

// MARK: - Byggeklodser

/// Stort hvidt kort med afrundede hjørner (indholdslaget, ingen glas).
struct CardBackground: ViewModifier {
    var fill: Color = Palette.surface
    var radius: CGFloat = 20
    func body(content: Content) -> some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fill, in: .rect(cornerRadius: radius))
    }
}

extension View {
    func card(_ fill: Color = Palette.surface, radius: CGFloat = 20) -> some View {
        modifier(CardBackground(fill: fill, radius: radius))
    }
}

/// Pilleformet knap, mindst 48 pt høj.
struct PillButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, quiet, dark }
    var kind: Kind = .primary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typo.body(16, .semibold))
            .padding(.horizontal, 20)
            .frame(minHeight: 48)
            .frame(maxWidth: .infinity)
            .foregroundStyle(foreground)
            .background(background, in: .capsule)
            .overlay {
                if kind == .quiet { Capsule().strokeBorder(Palette.hairline, lineWidth: 1) }
            }
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.snappy(duration: 0.18), value: configuration.isPressed)
            .contentShape(.capsule)
    }

    private var foreground: Color {
        switch kind {
        case .primary: .white
        case .secondary: Palette.moss
        case .quiet: Palette.ink
        case .dark: Palette.nightHighlight
        }
    }
    private var background: Color {
        switch kind {
        case .primary: Palette.moss
        case .secondary: Palette.mossLight
        case .quiet: Palette.surface
        case .dark: Palette.night
        }
    }
}

extension ButtonStyle where Self == PillButtonStyle {
    static var pill: PillButtonStyle { PillButtonStyle() }
    static func pill(_ kind: PillButtonStyle.Kind) -> PillButtonStyle { PillButtonStyle(kind: kind) }
}

/// Lille mærkat ("Exemple", "Secret local" …).
struct Tag: View {
    let text: String
    var fg: Color = Palette.moss
    var bg: Color = Palette.mossLight
    var icon: String? = nil

    var body: some View {
        HStack(spacing: 4) {
            if let icon { Image(systemName: icon).font(.system(size: 11, weight: .semibold)) }
            Text(text)
        }
        .font(Typo.body(12, .semibold, relativeTo: .caption))
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .foregroundStyle(fg)
        .background(bg, in: .capsule)
    }
}

/// Overskrift i en sektion.
struct SectionTitle: View {
    let text: String
    var body: some View {
        Text(text)
            .font(Typo.display(20, .bold, relativeTo: .title3))
            .foregroundStyle(Palette.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Mærket for Det Økologiske Spisemærke.
struct OrganicTag: View {
    var dark = false
    var body: some View {
        Tag(text: L("tag.organic"), fg: dark ? Palette.night : Palette.moss,
            bg: dark ? Palette.nightHighlight : Palette.mossLight, icon: "checkmark.seal")
    }
}
