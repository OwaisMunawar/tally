import SwiftUI
import TallyCore

/// The category's symbol on a tinted circle.
public struct CategoryIcon: View {
    private let category: TransactionCategory
    @ScaledMetric private var size: CGFloat

    public init(_ category: TransactionCategory, size: CGFloat = 36) {
        self.category = category
        _size = ScaledMetric(wrappedValue: size, relativeTo: .body)
    }

    public var body: some View {
        Image(systemName: category.systemImage)
            .font(.system(size: size * 0.45, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(TallyTheme.color(for: category).gradient, in: .circle)
            .accessibilityHidden(true)
    }
}

/// Says where a category came from: the user, a rule, or the on-device model
/// with its confidence. Honesty about provenance is the point.
public struct CategorizationBadge: View {
    private let source: CategorizationSource

    public init(_ source: CategorizationSource) {
        self.source = source
    }

    public var body: some View {
        HStack(spacing: 3) {
            Image(systemName: symbol).imageScale(.small)
            Text(title)
        }
        .font(.caption2.weight(.semibold))
        .lineLimit(1)
        .fixedSize()
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .foregroundStyle(tint)
        .background(tint.opacity(0.14), in: .capsule)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var title: String {
        switch source {
        case .manual: "You"
        case .rule(_, let learned): learned ? "Learned" : "Rule"
        case .model(let confidence): "AI \(confidence)%"
        case .uncategorized: "Review"
        }
    }

    private var symbol: String {
        switch source {
        case .manual: "person.fill"
        case .rule(_, let learned): learned ? "brain" : "list.bullet.rectangle"
        case .model: "apple.intelligence"
        case .uncategorized: "questionmark.circle"
        }
    }

    private var tint: Color {
        switch source {
        case .manual: .secondary
        case .rule: TallyTheme.accent
        case .model(let confidence): confidence >= 75 ? .purple : TallyTheme.warning
        case .uncategorized: TallyTheme.warning
        }
    }

    private var accessibilityText: String {
        switch source {
        case .manual: "Categorised by you"
        case .rule(let keyword, let learned): learned ? "Categorised by a rule you taught: \(keyword)" : "Categorised by keyword rule \(keyword)"
        case .model(let confidence): "Categorised on device by Apple Intelligence, \(confidence) percent confident"
        case .uncategorized: "Needs review"
        }
    }
}

/// A money amount with tabular digits; inflows are tinted positive.
public struct MoneyText: View {
    public enum Style {
        case standard, signed, hero
    }

    private let money: Money
    private let style: Style

    public init(_ money: Money, style: Style = .standard) {
        self.money = money
        self.style = style
    }

    public var body: some View {
        Text(text)
            .monospacedDigit()
            .font(style == .hero ? .system(.largeTitle, design: .rounded, weight: .bold) : .body.weight(.medium))
            .foregroundStyle(style == .signed && money.isPositive ? TallyTheme.positive : .primary)
            .contentTransition(.numericText())
    }

    private var text: String {
        style == .signed && money.isPositive ? "+" + money.formatted() : money.formatted()
    }
}

/// A small headline figure with a caption.
public struct StatTile: View {
    private let title: String
    private let value: String
    private let caption: String?
    private let systemImage: String

    public init(title: String, value: String, caption: String? = nil, systemImage: String) {
        self.title = title
        self.value = value
        self.caption = caption
        self.systemImage = systemImage
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: TallyTheme.Spacing.xSmall) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            if let caption {
                Text(caption).font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
