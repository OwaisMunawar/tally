import Foundation

/// Where a transaction's category came from, so the UI can be honest about it.
public enum CategorizationSource: Hashable, Sendable, Codable {
    /// Picked or confirmed by the user.
    case manual
    /// Matched a keyword rule; `learned` rules come from the user's own corrections.
    case rule(keyword: String, learned: Bool)
    /// Suggested by the on-device model with a confidence from 0 to 100.
    case model(confidence: Int)
    /// Imported without a category and not yet reviewed.
    case uncategorized

    public var needsReview: Bool {
        switch self {
        case .uncategorized: true
        case .model(let confidence): confidence < 60
        case .manual, .rule: false
        }
    }
}

/// One movement of money. Negative amounts are outflows.
public struct LedgerTransaction: Identifiable, Hashable, Sendable, Codable {
    public var id: UUID
    public var accountID: UUID
    public var payee: String
    public var amount: Money
    public var category: TransactionCategory
    public var categorization: CategorizationSource
    public var date: Date
    public var notes: String
    public var tags: [String]
    public var recurringID: UUID?

    public init(
        id: UUID = UUID(),
        accountID: UUID,
        payee: String,
        amount: Money,
        category: TransactionCategory,
        categorization: CategorizationSource = .manual,
        date: Date,
        notes: String = "",
        tags: [String] = [],
        recurringID: UUID? = nil
    ) {
        self.id = id
        self.accountID = accountID
        self.payee = payee
        self.amount = amount
        self.category = category
        self.categorization = categorization
        self.date = date
        self.notes = notes
        self.tags = tags
        self.recurringID = recurringID
    }

    public var isOutflow: Bool { amount.isNegative }
}
