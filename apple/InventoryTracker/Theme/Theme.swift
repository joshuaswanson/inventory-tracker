import SwiftUI

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

enum Theme {
    static let primary = Color(hex: 0x0891B2)
    static let primaryDark = Color(hex: 0x0E7490)
    static let primaryDarker = Color(hex: 0x155E75)
    static let primaryBackground = Color(hex: 0xECFEFF)
    static let green = Color(hex: 0x10B981)
    static let greenLight = Color(hex: 0xD1FAE5)
    static let amber = Color(hex: 0xF59E0B)
    static let amberLight = Color(hex: 0xFEF3C7)
    static let red = Color(hex: 0xEF4444)
    static let redDark = Color(hex: 0xDC2626)
    static let redLight = Color(hex: 0xFEE2E2)
    static let purple = Color(hex: 0x8B5CF6)
    static let purpleLight = Color(hex: 0xEDE9FE)
    static let background = Color(hex: 0xF0FDFA)
    static let surface = Color.white
    static let border = Color(hex: 0xE2E8F0)
    static let borderLight = Color(hex: 0xF1F5F9)
    static let text = Color(hex: 0x0F172A)
    static let textSecondary = Color(hex: 0x64748B)
    static let textTertiary = Color(hex: 0x94A3B8)

    static let radius: CGFloat = 12
    static let radiusSmall: CGFloat = 8
    static let pagePadding: CGFloat = 32
    static let compactPadding: CGFloat = 16
    static let sidebarWidth: CGFloat = 240
    static let wideLayoutMinimumWidth: CGFloat = 900

    static let sidebarGradient = LinearGradient(
        colors: [primaryDarker, primaryDark],
        startPoint: .top,
        endPoint: .bottom
    )
}

extension EnvironmentValues {
    @Entry var isWideLayout = true
}

private struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radius))
            .overlay(RoundedRectangle(cornerRadius: Theme.radius).strokeBorder(Theme.border))
            .shadow(color: .black.opacity(0.06), radius: 1.5, y: 1)
    }
}

extension View {
    func card() -> some View {
        modifier(CardBackground())
    }

    func sectionLabel(size: CGFloat = 12, tracking: CGFloat = 0.5) -> some View {
        font(.system(size: size, weight: .semibold))
            .textCase(.uppercase)
            .tracking(tracking)
            .foregroundStyle(Theme.textSecondary)
    }
}

enum ThemedButtonKind {
    case primary, secondary, danger
}

struct ThemedButtonStyle: ButtonStyle {
    var kind: ThemedButtonKind = .primary

    func makeBody(configuration: Configuration) -> some View {
        ThemedButtonBody(kind: kind, configuration: configuration)
    }
}

private struct ThemedButtonBody: View {
    let kind: ThemedButtonKind
    let configuration: ButtonStyleConfiguration
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovering = false

    private var isHighlighted: Bool { (isHovering || configuration.isPressed) && isEnabled }

    private var fill: Color {
        switch kind {
        case .primary: isHighlighted ? Theme.primaryDark : Theme.primary
        case .secondary: isHighlighted ? Theme.borderLight : Theme.surface
        case .danger: isHighlighted ? Theme.redDark : Theme.red
        }
    }

    var body: some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(kind == .secondary ? Theme.text : .white)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(fill, in: RoundedRectangle(cornerRadius: Theme.radiusSmall))
            .overlay {
                if kind == .secondary {
                    RoundedRectangle(cornerRadius: Theme.radiusSmall).strokeBorder(Theme.border)
                }
            }
            .opacity(isEnabled ? 1 : 0.5)
            .contentShape(Rectangle())
            .onHover { isHovering = $0 }
    }
}

extension ButtonStyle where Self == ThemedButtonStyle {
    static var themedPrimary: ThemedButtonStyle { ThemedButtonStyle(kind: .primary) }
    static var themedSecondary: ThemedButtonStyle { ThemedButtonStyle(kind: .secondary) }
    static var themedDanger: ThemedButtonStyle { ThemedButtonStyle(kind: .danger) }
}

struct RowIconButton: View {
    let systemImage: String
    var isDestructive = false
    let label: String
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .medium))
                .frame(width: 30, height: 28)
                .foregroundStyle(foreground)
                .background(background, in: RoundedRectangle(cornerRadius: 6))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .help(label)
        .onHover { isHovering = $0 }
    }

    private var foreground: Color {
        if isDestructive { return Theme.red }
        return isHovering ? Theme.text : Theme.textSecondary
    }

    private var background: Color {
        guard isHovering else { return .clear }
        return isDestructive ? Theme.redLight : Theme.border
    }
}
