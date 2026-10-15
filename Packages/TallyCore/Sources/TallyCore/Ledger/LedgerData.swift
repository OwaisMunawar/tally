import Foundation

/// Everything Tally knows, as plain values. Repositories load and save this;
/// the query engine, tools and widgets only ever read it.
public struct LedgerData: Hashable, Sendable {
    public var accounts: [Account]
    public var transactions: [LedgerTransaction]
    public var budgets: [Budget]
    public var recurring: [RecurringTransaction]
    public var rules: [CategoryRule]
    public var rates: ExchangeRateTable

    public init(
        accounts: [Account] = [],
        transactions: [LedgerTransaction] = [],
        budgets: [Budget] = [],
        recurring: [RecurringTransaction] = [],
        rules: [CategoryRule] = [],
        rates: ExchangeRateTable
    ) {
        self.accounts = accounts
        self.transactions = transactions
        self.budgets = budgets
        self.recurring = recurring
        self.rules = rules
        self.rates = rates
    }

    public var baseCurrency: CurrencyCode { rates.baseCurrency }

    public static func empty(baseCurrency: CurrencyCode = .usd) -> LedgerData {
        LedgerData(rates: .baseOnly(baseCurrency))
    }
}
