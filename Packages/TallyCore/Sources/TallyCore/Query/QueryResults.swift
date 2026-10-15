import Foundation

public struct SpendSummary: Hashable, Sendable {
    /// Net spending as a positive amount; refunds in a spending category reduce it.
    public let total: Money
    public let transactionCount: Int
}

public struct CategoryTotal: Identifiable, Hashable, Sendable {
    public let category: TransactionCategory
    public let total: Money
    public let transactionCount: Int
    public var id: TransactionCategory { category }
}

public struct PayeeTotal: Identifiable, Hashable, Sendable {
    public let payee: String
    public let total: Money
    public let transactionCount: Int
    public var id: String { payee }
}

public struct RangeComparison: Hashable, Sendable {
    public let first: SpendSummary
    public let second: SpendSummary
    /// `first - second`: positive means more was spent in the first range.
    public let difference: Money
    /// Change from `second` to `first` in percent, rounded to one decimal place.
    /// `nil` when nothing was spent in `second`.
    public let percentChange: Decimal?
}

public struct DailySpend: Identifiable, Hashable, Sendable {
    public let day: Date
    public let total: Money
    public var id: Date { day }
}

public struct CashFlowPoint: Identifiable, Hashable, Sendable {
    public let periodStart: Date
    public let inflow: Money
    public let outflow: Money
    public let net: Money
    public var id: Date { periodStart }
}

/// Filters for transaction search. Every field is optional and they combine with AND.
public struct TransactionSearch: Hashable, Sendable {
    public var text: String?
    public var categories: Set<TransactionCategory>?
    public var range: DateRange?
    public var minimumMagnitude: Money?
    public var limit: Int

    public init(
        text: String? = nil,
        categories: Set<TransactionCategory>? = nil,
        range: DateRange? = nil,
        minimumMagnitude: Money? = nil,
        limit: Int = 20
    ) {
        self.text = text
        self.categories = categories
        self.range = range
        self.minimumMagnitude = minimumMagnitude
        self.limit = limit
    }
}
