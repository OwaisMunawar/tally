import AppIntents
import TallyCore

/// Spending categories as Siri and Shortcuts see them.
enum CategoryAppEnum: String, AppEnum {
    case groceries, dining, transport, housing, utilities, subscriptions, shopping, travel, health, entertainment, other

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Category"

    static let caseDisplayRepresentations: [CategoryAppEnum: DisplayRepresentation] = [
        .groceries: DisplayRepresentation(title: "Groceries", image: .init(systemName: "cart.fill")),
        .dining: DisplayRepresentation(title: "Dining", image: .init(systemName: "fork.knife"), synonyms: ["food", "eating out", "restaurants"]),
        .transport: DisplayRepresentation(title: "Transport", image: .init(systemName: "tram.fill"), synonyms: ["travel to work", "commute"]),
        .housing: DisplayRepresentation(title: "Housing", image: .init(systemName: "house.fill"), synonyms: ["rent"]),
        .utilities: DisplayRepresentation(title: "Utilities", image: .init(systemName: "bolt.fill"), synonyms: ["bills"]),
        .subscriptions: DisplayRepresentation(title: "Subscriptions", image: .init(systemName: "repeat.circle.fill")),
        .shopping: DisplayRepresentation(title: "Shopping", image: .init(systemName: "bag.fill")),
        .travel: DisplayRepresentation(title: "Travel", image: .init(systemName: "airplane"), synonyms: ["trips"]),
        .health: DisplayRepresentation(title: "Health", image: .init(systemName: "cross.case.fill"), synonyms: ["pharmacy", "gym"]),
        .entertainment: DisplayRepresentation(title: "Entertainment", image: .init(systemName: "ticket.fill"), synonyms: ["fun"]),
        .other: DisplayRepresentation(title: "Other", image: .init(systemName: "square.grid.2x2.fill")),
    ]

    var category: TransactionCategory {
        TransactionCategory(rawValue: rawValue) ?? .other
    }
}

enum SpendPeriodAppEnum: String, AppEnum {
    case thisMonth = "this_month"
    case lastMonth = "last_month"
    case last30Days = "last_30_days"
    case thisYear = "this_year"

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Period"

    static let caseDisplayRepresentations: [SpendPeriodAppEnum: DisplayRepresentation] = [
        .thisMonth: "This Month",
        .lastMonth: "Last Month",
        .last30Days: "Last 30 Days",
        .thisYear: "This Year",
    ]
}
