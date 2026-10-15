import Foundation

/// A template that materialises into real transactions on schedule.
public struct RecurringTransaction: Identifiable, Hashable, Sendable, Codable {
    public var id: UUID
    public var accountID: UUID
    public var payee: String
    public var amount: Money
    public var category: TransactionCategory
    public var rule: RecurrenceRule
    public var startDate: Date
    public var endDate: Date?

    public init(
        id: UUID = UUID(),
        accountID: UUID,
        payee: String,
        amount: Money,
        category: TransactionCategory,
        rule: RecurrenceRule,
        startDate: Date,
        endDate: Date? = nil
    ) {
        self.id = id
        self.accountID = accountID
        self.payee = payee
        self.amount = amount
        self.category = category
        self.rule = rule
        self.startDate = startDate
        self.endDate = endDate
    }

    /// Transactions due in `range` that are not already in `existing`.
    ///
    /// Idempotent by design: running it twice for the same range, or after the
    /// app was closed for a month, never duplicates a rent payment.
    public func dueTransactions(in range: DateRange, existing: [LedgerTransaction], calendar: Calendar) -> [LedgerTransaction] {
        let alreadyPosted = Set(
            existing
                .filter { $0.recurringID == id }
                .map { calendar.startOfDay(for: $0.date) }
        )
        return rule
            .occurrences(anchoredAt: startDate, in: range, until: endDate, calendar: calendar)
            .filter { !alreadyPosted.contains(calendar.startOfDay(for: $0)) }
            .map { date in
                LedgerTransaction(
                    accountID: accountID,
                    payee: payee,
                    amount: amount,
                    category: category,
                    categorization: .manual,
                    date: date,
                    tags: ["recurring"],
                    recurringID: id
                )
            }
    }
}
