import Foundation

/// A repository backed by a value in memory. Used by tests, SwiftUI previews
/// and as the fallback when the on-disk store cannot be opened.
public actor InMemoryLedgerRepository: LedgerRepository {
    private var data: LedgerData

    public init(_ data: LedgerData = .empty()) {
        self.data = data
    }

    public func load() -> LedgerData {
        data
    }

    public func upsert(_ transactions: [LedgerTransaction]) {
        for transaction in transactions {
            if let index = data.transactions.firstIndex(where: { $0.id == transaction.id }) {
                data.transactions[index] = transaction
            } else {
                data.transactions.append(transaction)
            }
        }
    }

    public func deleteTransaction(id: UUID) throws(RepositoryError) {
        guard let index = data.transactions.firstIndex(where: { $0.id == id }) else { throw .notFound(id) }
        data.transactions.remove(at: index)
    }

    public func upsert(_ account: Account) {
        replaceOrAppend(account, in: &data.accounts)
    }

    public func upsert(_ budget: Budget) {
        replaceOrAppend(budget, in: &data.budgets)
    }

    public func deleteBudget(id: UUID) throws(RepositoryError) {
        guard data.budgets.contains(where: { $0.id == id }) else { throw .notFound(id) }
        data.budgets.removeAll { $0.id == id }
    }

    public func upsert(_ recurring: RecurringTransaction) {
        replaceOrAppend(recurring, in: &data.recurring)
    }

    public func upsert(_ rule: CategoryRule) {
        data.rules.removeAll { $0.keyword == rule.keyword }
        data.rules.append(rule)
    }

    public func deleteRule(keyword: String) {
        data.rules.removeAll { $0.keyword == keyword }
    }

    public func save(_ rates: ExchangeRateTable) {
        data.rates = rates
    }

    public func replaceAll(with data: LedgerData) {
        self.data = data
    }

    private func replaceOrAppend<Value: Identifiable>(_ value: Value, in values: inout [Value]) {
        if let index = values.firstIndex(where: { $0.id == value.id }) {
            values[index] = value
        } else {
            values.append(value)
        }
    }
}
