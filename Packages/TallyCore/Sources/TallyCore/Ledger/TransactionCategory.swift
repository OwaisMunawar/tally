import Foundation

/// The fixed category set.
///
/// A closed enum (rather than user-defined strings) is what lets the on-device
/// model's output be constrained with `anyOf` and lets rules, budgets and charts
/// agree on names. Users personalise with tags, not new categories.
public enum TransactionCategory: String, CaseIterable, Identifiable, Hashable, Sendable, Codable {
    case groceries
    case dining
    case transport
    case housing
    case utilities
    case subscriptions
    case shopping
    case travel
    case health
    case entertainment
    case income
    case transfer
    case other

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .groceries: "Groceries"
        case .dining: "Dining"
        case .transport: "Transport"
        case .housing: "Housing"
        case .utilities: "Utilities"
        case .subscriptions: "Subscriptions"
        case .shopping: "Shopping"
        case .travel: "Travel"
        case .health: "Health"
        case .entertainment: "Entertainment"
        case .income: "Income"
        case .transfer: "Transfer"
        case .other: "Other"
        }
    }

    /// One-line definition used in model instructions so the model and the
    /// user share the same idea of what each bucket holds.
    public var definition: String {
        switch self {
        case .groceries: "supermarkets and food bought to cook at home"
        case .dining: "restaurants, cafes, coffee, takeaway and food delivery"
        case .transport: "fuel, public transit, taxis, ride-hailing and parking"
        case .housing: "rent, mortgage and home maintenance"
        case .utilities: "electricity, gas, water, internet and phone bills"
        case .subscriptions: "recurring digital services, streaming, software and memberships"
        case .shopping: "clothes, electronics, household goods and general retail"
        case .travel: "flights, hotels and spending while on a trip"
        case .health: "pharmacy, doctors, dentists and fitness"
        case .entertainment: "cinema, concerts, games, events and hobbies"
        case .income: "salary, refunds and money received"
        case .transfer: "moving money between the user's own accounts"
        case .other: "anything that does not fit another category"
        }
    }

    public var systemImage: String {
        switch self {
        case .groceries: "cart.fill"
        case .dining: "fork.knife"
        case .transport: "tram.fill"
        case .housing: "house.fill"
        case .utilities: "bolt.fill"
        case .subscriptions: "repeat.circle.fill"
        case .shopping: "bag.fill"
        case .travel: "airplane"
        case .health: "cross.case.fill"
        case .entertainment: "ticket.fill"
        case .income: "arrow.down.circle.fill"
        case .transfer: "arrow.left.arrow.right"
        case .other: "square.grid.2x2.fill"
        }
    }

    /// Whether outflows in this category count as spending. Transfers move money
    /// between the user's own accounts, and income is not an expense.
    public var isSpending: Bool {
        self != .income && self != .transfer
    }

    public static var spendingCases: [TransactionCategory] {
        allCases.filter(\.isSpending)
    }
}

/// Words people use for groups of categories ("food" is groceries plus dining).
public enum CategoryVocabulary {
    public static let groups: [String: Set<TransactionCategory>] = [
        "food": [.groceries, .dining],
        "eating_out": [.dining],
        "restaurants": [.dining],
        "coffee": [.dining],
        "bills": [.housing, .utilities, .subscriptions],
        "rent": [.housing],
        "commute": [.transport],
        "trips": [.travel],
        "fun": [.entertainment],
    ]

    /// Every token a tool argument may carry, for `@Guide(.anyOf:)`.
    public static var tokens: [String] {
        ["all"] + TransactionCategory.allCases.map(\.rawValue) + groups.keys.sorted()
    }

    /// Resolves a token to the categories it covers. `nil` means "no filter".
    public static func categories(for token: String) -> Set<TransactionCategory>? {
        let key = token.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().replacingOccurrences(of: " ", with: "_")
        if key.isEmpty || key == "all" || key == "everything" || key == "any" { return nil }
        if let category = TransactionCategory(rawValue: key) { return [category] }
        if let group = groups[key] { return group }
        if let category = TransactionCategory.allCases.first(where: { $0.displayName.lowercased() == key }) {
            return [category]
        }
        return nil
    }

    public static func label(for categories: Set<TransactionCategory>?) -> String {
        guard let categories else { return "all spending" }
        if let group = groups.first(where: { $0.value == categories && $0.value.count > 1 }) {
            return group.key.replacingOccurrences(of: "_", with: " ")
        }
        return categories.sorted { $0.rawValue < $1.rawValue }.map(\.displayName).joined(separator: " + ")
    }
}
