import SwiftUI

enum Tone {
    case green, amber, red, blue, purple, gray

    var background: Color {
        switch self {
        case .green: Theme.greenLight
        case .amber: Theme.amberLight
        case .red: Theme.redLight
        case .blue: Theme.primaryBackground
        case .purple: Theme.purpleLight
        case .gray: Theme.borderLight
        }
    }

    var badgeText: Color {
        switch self {
        case .green: Color(hex: 0x065F46)
        case .amber: Color(hex: 0x92400E)
        case .red: Color(hex: 0x991B1B)
        case .blue: Theme.primaryDarker
        case .purple: Color(hex: 0x5B21B6)
        case .gray: Theme.textSecondary
        }
    }

    var icon: Color {
        switch self {
        case .green: Theme.green
        case .amber: Theme.amber
        case .red: Theme.red
        case .blue: Theme.primary
        case .purple: Theme.purple
        case .gray: Theme.textSecondary
        }
    }
}

struct Badge: View {
    let text: String
    let tone: Tone

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .tracking(0.3)
            .lineLimit(1)
            .fixedSize()
            .foregroundStyle(tone.badgeText)
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .background(tone.background, in: Capsule())
    }
}

struct StockBadge: View {
    let metrics: ItemMetrics

    var body: some View {
        if metrics.currentInventory <= 0 {
            Badge(text: "Out of Stock", tone: .red)
        } else if metrics.needsReorder {
            Badge(text: "Low Stock", tone: .amber)
        } else {
            Badge(text: "In Stock", tone: .green)
        }
    }
}

struct ExpirationBadge: View {
    let days: Int?
    var isEstimated = false

    var body: some View {
        if let days {
            switch days {
            case ..<0: Badge(text: isEstimated ? "Likely expired" : "Expired", tone: .red)
            case 0: Badge(text: "Expires today", tone: .red)
            case 1...7: Badge(text: "\(days)d left", tone: .red)
            case 8...30: Badge(text: "\(days)d left", tone: .amber)
            default: Badge(text: "\(days)d left", tone: .green)
            }
        }
    }
}

struct StockBar: View {
    let stock: Int
    let reorderLevel: Int
    let needsReorder: Bool
    let unit: String

    private var fraction: Double {
        let maximum = max(reorderLevel * 3, stock, 1)
        return min(1, max(0, Double(stock) / Double(maximum)))
    }

    private var color: Color {
        if stock <= 0 { return Theme.red }
        return needsReorder ? Theme.amber : Theme.green
    }

    var body: some View {
        HStack(spacing: 8) {
            Text("\(stock) \(unit)")
                .font(.system(size: 13))
                .foregroundStyle(Theme.text)
                .lineLimit(1)
                .fixedSize()
            Capsule()
                .fill(Theme.borderLight)
                .frame(maxWidth: 80)
                .frame(height: 6)
                .overlay(alignment: .leading) {
                    GeometryReader { geometry in
                        Capsule().fill(color).frame(width: geometry.size.width * fraction)
                    }
                }
        }
    }
}

struct StatCard: View {
    var systemImage: String?
    var tone: Tone = .blue
    let label: String
    let value: String
    var valueColor: Color = Theme.text
    var subtitle: String?
    var action: (() -> Void)?
    @State private var isHovering = false

    var body: some View {
        if let action {
            Button(action: action) { content }
                .buttonStyle(.plain)
                .onHover { isHovering = $0 }
        } else {
            content
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 18))
                    .foregroundStyle(tone.icon)
                    .frame(width: 40, height: 40)
                    .background(tone.background, in: RoundedRectangle(cornerRadius: 10))
                    .padding(.bottom, 8)
            }
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .textCase(.uppercase)
                .tracking(0.5)
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
            Text(value)
                .font(.system(size: 28, weight: .bold))
                .tracking(-1)
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .card()
        .overlay {
            if isHovering {
                RoundedRectangle(cornerRadius: Theme.radius).strokeBorder(Theme.primary)
            }
        }
        .contentShape(Rectangle())
    }
}

struct FilterChip: View {
    let label: String
    let count: Int
    let isActive: Bool
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Text(count > 0 ? "\(label) (\(count))" : label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(foreground)
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(isActive ? Theme.primary : Theme.surface, in: Capsule())
                .overlay(Capsule().strokeBorder(isActive ? Theme.primary : Theme.border))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }

    private var foreground: Color {
        if isActive { return .white }
        return isHovering ? Theme.primary : Theme.textSecondary
    }
}

struct FilterOption<Value: Hashable>: Identifiable {
    let value: Value
    let label: String
    let count: Int

    var id: Value { value }
}

struct FilterChips<Value: Hashable>: View {
    let options: [FilterOption<Value>]
    @Binding var selection: Value

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(options) { option in
                    FilterChip(label: option.label, count: option.count, isActive: selection == option.value) {
                        selection = option.value
                    }
                }
            }
        }
        .padding(.bottom, 16)
    }
}

struct SearchField: View {
    let prompt: String
    @Binding var text: String
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.textTertiary)
            TextField("", text: $text, prompt: Text(prompt).foregroundStyle(Theme.textTertiary))
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(Theme.text)
                .focused($isFocused)
        }
        .padding(.horizontal, 10)
        .frame(width: 240, height: 34)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radiusSmall))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusSmall)
                .strokeBorder(isFocused ? Theme.primary : Theme.border)
        )
    }
}

struct EmptyState: View {
    var systemImage: String?
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 4) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 40))
                    .foregroundStyle(Theme.textTertiary.opacity(0.5))
                    .padding(.bottom, 12)
            }
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .padding(.horizontal, 20)
    }
}

struct DetailSection<Content: View>: View {
    let title: String
    var systemImage: String?
    var iconColor: Color = Theme.textSecondary
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 13))
                        .foregroundStyle(iconColor)
                }
                Text(title).sectionLabel(size: 13)
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(20)
        .card()
    }
}

struct InfoRow<Value: View>: View {
    let label: String
    var showsDivider = true
    @ViewBuilder let value: Value

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                Text(label).foregroundStyle(Theme.textSecondary)
                Spacer(minLength: 0)
                value
                    .fontWeight(.medium)
                    .foregroundStyle(Theme.text)
                    .multilineTextAlignment(.trailing)
            }
            .font(.system(size: 13))
            .padding(.vertical, 8)
            if showsDivider {
                Divider().overlay(Theme.borderLight)
            }
        }
    }
}

extension InfoRow where Value == Text {
    init(_ label: String, value: String, showsDivider: Bool = true) {
        self.init(label: label, showsDivider: showsDivider) { Text(value) }
    }
}

struct MiniRow<Content: View>: View {
    var showsDivider = true
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) { content }
                .font(.system(size: 13))
                .foregroundStyle(Theme.text)
                .padding(.vertical, 6)
            if showsDivider {
                Divider().overlay(Theme.borderLight)
            }
        }
    }
}

struct PlaceholderText: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(Theme.textTertiary)
    }
}
