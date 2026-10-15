import SwiftUI
import TallyCore

/// Design tokens. Views reach for these instead of literal values so spacing,
/// radii and category colours stay consistent across the app and widgets.
public enum TallyTheme {
    public enum Spacing {
        public static let xSmall: CGFloat = 4
        public static let small: CGFloat = 8
        public static let medium: CGFloat = 12
        public static let large: CGFloat = 16
        public static let xLarge: CGFloat = 24
    }

    public enum Radius {
        public static let card: CGFloat = 24
        public static let control: CGFloat = 14
        public static let accountCard: CGFloat = 22
    }

    public static let accent = Color(red: 0.18, green: 0.42, blue: 0.98)
    public static let positive = Color(red: 0.13, green: 0.66, blue: 0.42)
    public static let warning = Color(red: 0.98, green: 0.62, blue: 0.10)
    public static let negative = Color(red: 0.93, green: 0.26, blue: 0.30)

    public static func color(for category: TransactionCategory) -> Color {
        switch category {
        case .groceries: Color(red: 0.34, green: 0.72, blue: 0.29)
        case .dining: Color(red: 0.98, green: 0.55, blue: 0.16)
        case .transport: Color(red: 0.20, green: 0.55, blue: 0.95)
        case .housing: Color(red: 0.40, green: 0.36, blue: 0.86)
        case .utilities: Color(red: 0.95, green: 0.76, blue: 0.10)
        case .subscriptions: Color(red: 0.66, green: 0.36, blue: 0.90)
        case .shopping: Color(red: 0.93, green: 0.33, blue: 0.58)
        case .travel: Color(red: 0.10, green: 0.70, blue: 0.75)
        case .health: Color(red: 0.90, green: 0.30, blue: 0.32)
        case .entertainment: Color(red: 0.28, green: 0.78, blue: 0.62)
        case .income: positive
        case .transfer: Color.gray
        case .other: Color(red: 0.55, green: 0.58, blue: 0.64)
        }
    }

    public static func color(for state: BudgetStatus.State) -> Color {
        switch state {
        case .onTrack: positive
        case .nearLimit: warning
        case .over: negative
        }
    }

    /// Card stock for account cards: deep enough that white text and the foil
    /// sheen both read in light and dark mode.
    public static func cardGradient(for kind: Account.Kind) -> LinearGradient {
        let colors: [Color] = switch kind {
        case .bank: [Color(red: 0.09, green: 0.16, blue: 0.38), Color(red: 0.17, green: 0.36, blue: 0.80)]
        case .card: [Color(red: 0.10, green: 0.10, blue: 0.14), Color(red: 0.30, green: 0.27, blue: 0.40)]
        case .cash: [Color(red: 0.05, green: 0.34, blue: 0.30), Color(red: 0.15, green: 0.62, blue: 0.50)]
        }
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}
