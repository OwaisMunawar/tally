import Foundation

/// Read-only analytics over a ledger, in the base currency.
///
/// This is the single source of numbers in Tally. Charts, budgets, widgets,
/// App Intents and every Ask Tally tool call land here, which is what makes
/// it possible to promise that an AI answer can only quote figures this
/// engine produced.
///
/// Every transaction is converted to the base currency once, at init, with a
/// single rounding step per transaction (what a statement would show), and all
/// later sums are exact integer arithmetic.
public struct LedgerQueryEngine: Sendable {
    public let data: LedgerData
    public let calendar: Calendar
    public let now: Date

    private let entries: [Entry]
    private let baseByID: [UUID: Money]

    private struct Entry: Sendable {
        let transaction: LedgerTransaction
        let base: Money
    }

    public init(data: LedgerData, calendar: Calendar, now: Date) throws(FXError) {
        self.data = data
        self.calendar = calendar
        self.now = now
        var entries: [Entry] = []
        entries.reserveCapacity(data.transactions.count)
        for transaction in data.transactions {
            entries.append(Entry(transaction: transaction, base: try data.rates.toBase(transaction.amount)))
        }
        self.entries = entries.sorted { $0.transaction.date > $1.transaction.date }
        self.baseByID = Dictionary(entries.map { ($0.transaction.id, $0.base) }) { first, _ in first }
    }

    public var baseCurrency: CurrencyCode { data.baseCurrency }

    public var currentMonth: DateRange {
        .month(containing: now, calendar: calendar)
    }

    public var periodParser: PeriodParser {
        PeriodParser(calendar: calendar, now: now)
    }

    // MARK: Spending

    public func spending(in range: DateRange, categories: Set<TransactionCategory>? = nil) -> SpendSummary {
        let matching = spendingEntries(in: range, categories: categories)
        return SpendSummary(total: netSpend(matching), transactionCount: matching.count)
    }

    public func spendByCategory(in range: DateRange) -> [CategoryTotal] {
        Dictionary(grouping: spendingEntries(in: range, categories: nil), by: \.transaction.category)
            .map { category, entries in
                CategoryTotal(category: category, total: netSpend(entries), transactionCount: entries.count)
            }
            .filter { $0.total.isPositive }
            .sorted { $0.total.minorUnits != $1.total.minorUnits ? $0.total > $1.total : $0.category.rawValue < $1.category.rawValue }
    }

    public func compare(_ first: DateRange, with second: DateRange, categories: Set<TransactionCategory>? = nil) -> RangeComparison {
        let lhs = spending(in: first, categories: categories)
        let rhs = spending(in: second, categories: categories)
        let difference = Money(minorUnits: lhs.total.minorUnits - rhs.total.minorUnits, currency: baseCurrency)
        var percent: Decimal?
        if rhs.total.minorUnits != 0 {
            let raw = Decimal(difference.minorUnits) * 100 / Decimal(rhs.total.minorUnits)
            percent = RoundingPolicy.halfAwayFromZero.round(raw, scale: 1)
        }
        return RangeComparison(first: lhs, second: rhs, difference: difference, percentChange: percent)
    }

    public func topPayees(in range: DateRange, categories: Set<TransactionCategory>? = nil, limit: Int = 5) -> [PayeeTotal] {
        let groups = Dictionary(grouping: spendingEntries(in: range, categories: categories)) {
            PayeeNormalizer.normalize($0.transaction.payee)
        }
        return groups.values
            .compactMap { entries -> PayeeTotal? in
                guard let display = Self.displayName(for: entries.map(\.transaction.payee)) else { return nil }
                return PayeeTotal(payee: display, total: netSpend(entries), transactionCount: entries.count)
            }
            .filter { $0.total.isPositive }
            .sorted { $0.total.minorUnits != $1.total.minorUnits ? $0.total > $1.total : $0.payee < $1.payee }
            .prefix(max(0, limit))
            .map { $0 }
    }

    // MARK: Search

    public func find(_ search: TransactionSearch) -> [LedgerTransaction] {
        let needle = search.text.map(PayeeNormalizer.normalize).flatMap { $0.isEmpty ? nil : $0 }
        let minimum = search.minimumMagnitude.flatMap { try? data.rates.toBase($0) }
        return entries
            .lazy
            .filter { entry in
                let transaction = entry.transaction
                if let range = search.range, !range.contains(transaction.date) { return false }
                if let categories = search.categories, !categories.contains(transaction.category) { return false }
                if let minimum, entry.base.magnitude.minorUnits < minimum.minorUnits { return false }
                if let needle {
                    let haystack = PayeeNormalizer.normalize([transaction.payee, transaction.notes, transaction.tags.joined(separator: " ")]
                        .joined(separator: " "))
                    if !haystack.contains(needle) { return false }
                }
                return true
            }
            .prefix(max(0, search.limit))
            .map(\.transaction)
    }

    public func baseAmount(of transaction: LedgerTransaction) -> Money {
        baseByID[transaction.id] ?? (try? data.rates.toBase(transaction.amount)) ?? .zero(baseCurrency)
    }

    // MARK: Budgets

    public func budgetStatuses(in month: DateRange? = nil) -> [BudgetStatus] {
        let range = month ?? currentMonth
        return data.budgets
            .map { BudgetStatus(budget: $0, spent: spending(in: range, categories: [$0.category]).total) }
            .sorted { $0.progress > $1.progress }
    }

    /// Total left across every budget this month, the number on the widget.
    public func totalBudgetRemaining(in month: DateRange? = nil) -> (remaining: Money, limit: Money) {
        let statuses = budgetStatuses(in: month)
        let limit = statuses.reduce(Int64(0)) { $0 + $1.budget.monthlyLimit.minorUnits }
        let spent = statuses.reduce(Int64(0)) { $0 + $1.spent.minorUnits }
        return (Money(minorUnits: limit - spent, currency: baseCurrency), Money(minorUnits: limit, currency: baseCurrency))
    }

    // MARK: Series for charts

    public func dailySpend(in range: DateRange) -> [DailySpend] {
        let byDay = Dictionary(grouping: spendingEntries(in: range, categories: nil)) {
            calendar.startOfDay(for: $0.transaction.date)
        }
        var days: [DailySpend] = []
        var cursor = calendar.startOfDay(for: range.start)
        while cursor < range.end, cursor <= now {
            days.append(DailySpend(day: cursor, total: netSpend(byDay[cursor] ?? [])))
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return days
    }

    public func monthlyCashFlow(in range: DateRange) -> [CashFlowPoint] {
        range.months(calendar: calendar).map { month in
            var inflow: Int64 = 0
            var outflow: Int64 = 0
            for entry in entries where month.contains(entry.transaction.date) && entry.transaction.category != .transfer {
                if entry.base.isPositive { inflow += entry.base.minorUnits } else { outflow -= entry.base.minorUnits }
            }
            return CashFlowPoint(
                periodStart: month.start,
                inflow: Money(minorUnits: inflow, currency: baseCurrency),
                outflow: Money(minorUnits: outflow, currency: baseCurrency),
                net: Money(minorUnits: inflow - outflow, currency: baseCurrency)
            )
        }
    }

    // MARK: Balances

    public func balance(of account: Account) -> Money {
        let movement = data.transactions
            .filter { $0.accountID == account.id }
            .reduce(Int64(0)) { $0 + $1.amount.minorUnits }
        return Money(minorUnits: account.openingBalance.minorUnits + movement, currency: account.currency)
    }

    public var netWorth: Money {
        let total = data.accounts.reduce(Int64(0)) { sum, account in
            sum + ((try? data.rates.toBase(balance(of: account)).minorUnits) ?? 0)
        }
        return Money(minorUnits: total, currency: baseCurrency)
    }

    // MARK: Helpers

    private func spendingEntries(in range: DateRange, categories: Set<TransactionCategory>?) -> [Entry] {
        entries.filter { entry in
            let category = entry.transaction.category
            guard category.isSpending, range.contains(entry.transaction.date) else { return false }
            return categories?.contains(category) ?? true
        }
    }

    /// The spelling a merchant appears under most often, preferring the shorter
    /// one on ties, since bank descriptors only ever add noise.
    private static func displayName(for payees: [String]) -> String? {
        let counts = Dictionary(payees.map { ($0, 1) }, uniquingKeysWith: +)
        return counts.max { lhs, rhs in
            lhs.value != rhs.value ? lhs.value < rhs.value : lhs.key.count > rhs.key.count
        }?.key
    }

    private func netSpend(_ entries: [Entry]) -> Money {
        Money(minorUnits: -entries.reduce(Int64(0)) { $0 + $1.base.minorUnits }, currency: baseCurrency)
    }
}
