import Foundation
import SwiftData
import TallyCore

/// `LedgerRepository` over SwiftData.
///
/// A `@ModelActor` gives the repository its own serial context off the main
/// actor, so a CSV import of a few thousand rows never blocks scrolling. Callers
/// only ever see domain values; `@Model` objects never escape this actor.
@ModelActor
public actor SwiftDataLedgerRepository: LedgerRepository {
    public func load() throws(RepositoryError) -> LedgerData {
        do {
            let accounts = try modelContext.fetch(FetchDescriptor<AccountRecord>(sortBy: [SortDescriptor(\.sortOrder)])).map(\.domain)
            let transactions = try modelContext.fetch(FetchDescriptor<TransactionRecord>(sortBy: [SortDescriptor(\.date, order: .reverse)]))
                .map(\.domain)
            let budgets = try modelContext.fetch(FetchDescriptor<BudgetRecord>()).map(\.domain)
            let recurring = try modelContext.fetch(FetchDescriptor<RecurringRecord>()).map(\.domain)
            let rules = try modelContext.fetch(FetchDescriptor<CategoryRuleRecord>(sortBy: [SortDescriptor(\.createdAt)])).map(\.domain)
            return LedgerData(
                accounts: accounts,
                transactions: transactions,
                budgets: budgets.sorted { $0.category.rawValue < $1.category.rawValue },
                recurring: recurring,
                rules: rules,
                rates: try loadRates()
            )
        } catch let error as RepositoryError {
            throw error
        } catch {
            throw .storage(error.localizedDescription)
        }
    }

    public func upsert(_ transactions: [LedgerTransaction]) throws(RepositoryError) {
        try perform {
            let ids = transactions.map(\.id)
            let existing = try modelContext.fetch(FetchDescriptor<TransactionRecord>(predicate: #Predicate { ids.contains($0.id) }))
            let byID = Dictionary(existing.map { ($0.id, $0) }) { first, _ in first }
            for transaction in transactions {
                if let record = byID[transaction.id] {
                    record.update(from: transaction)
                } else {
                    modelContext.insert(TransactionRecord(transaction))
                }
            }
        }
    }

    public func deleteTransaction(id: UUID) throws(RepositoryError) {
        try perform {
            guard let record = try modelContext.fetch(FetchDescriptor<TransactionRecord>(predicate: #Predicate { $0.id == id })).first else {
                throw RepositoryError.notFound(id)
            }
            modelContext.delete(record)
        }
    }

    public func upsert(_ account: Account) throws(RepositoryError) {
        try perform {
            let id = account.id
            if let record = try modelContext.fetch(FetchDescriptor<AccountRecord>(predicate: #Predicate { $0.id == id })).first {
                record.update(from: account)
            } else {
                modelContext.insert(AccountRecord(account))
            }
        }
    }

    public func upsert(_ budget: Budget) throws(RepositoryError) {
        try perform {
            let id = budget.id
            if let record = try modelContext.fetch(FetchDescriptor<BudgetRecord>(predicate: #Predicate { $0.id == id })).first {
                record.update(from: budget)
            } else {
                modelContext.insert(BudgetRecord(budget))
            }
        }
    }

    public func deleteBudget(id: UUID) throws(RepositoryError) {
        try perform {
            guard let record = try modelContext.fetch(FetchDescriptor<BudgetRecord>(predicate: #Predicate { $0.id == id })).first else {
                throw RepositoryError.notFound(id)
            }
            modelContext.delete(record)
        }
    }

    public func upsert(_ recurring: RecurringTransaction) throws(RepositoryError) {
        try perform {
            let id = recurring.id
            if let record = try modelContext.fetch(FetchDescriptor<RecurringRecord>(predicate: #Predicate { $0.id == id })).first {
                record.update(from: recurring)
            } else {
                modelContext.insert(RecurringRecord(recurring))
            }
        }
    }

    public func upsert(_ rule: CategoryRule) throws(RepositoryError) {
        try perform {
            let keyword = rule.keyword
            if let record = try modelContext.fetch(FetchDescriptor<CategoryRuleRecord>(predicate: #Predicate { $0.keyword == keyword })).first {
                record.update(from: rule)
            } else {
                modelContext.insert(CategoryRuleRecord(rule))
            }
        }
    }

    public func deleteRule(keyword: String) throws(RepositoryError) {
        try perform {
            try modelContext.delete(model: CategoryRuleRecord.self, where: #Predicate { $0.keyword == keyword })
        }
    }

    public func save(_ rates: ExchangeRateTable) throws(RepositoryError) {
        try perform {
            try modelContext.delete(model: ExchangeRateRecord.self)
            for code in rates.currencies {
                guard let rate = rates.rate(for: code) else { continue }
                modelContext.insert(ExchangeRateRecord(
                    currencyCode: code.rawValue,
                    unitsOfBase: rate,
                    isBase: code == rates.baseCurrency,
                    updatedAt: rates.updatedAt
                ))
            }
        }
    }

    public func replaceAll(with data: LedgerData) throws(RepositoryError) {
        try perform {
            try modelContext.delete(model: TransactionRecord.self)
            try modelContext.delete(model: AccountRecord.self)
            try modelContext.delete(model: BudgetRecord.self)
            try modelContext.delete(model: RecurringRecord.self)
            try modelContext.delete(model: CategoryRuleRecord.self)
            data.accounts.forEach { modelContext.insert(AccountRecord($0)) }
            data.transactions.forEach { modelContext.insert(TransactionRecord($0)) }
            data.budgets.forEach { modelContext.insert(BudgetRecord($0)) }
            data.recurring.forEach { modelContext.insert(RecurringRecord($0)) }
            data.rules.forEach { modelContext.insert(CategoryRuleRecord($0)) }
        }
        try save(data.rates)
    }

    // MARK: Private

    private func loadRates() throws -> ExchangeRateTable {
        let records = try modelContext.fetch(FetchDescriptor<ExchangeRateRecord>())
        guard let base = records.first(where: \.isBase) else { return .baseOnly(.usd) }
        var table = ExchangeRateTable.baseOnly(CurrencyCode(base.currencyCode), updatedAt: base.updatedAt)
        for record in records where !record.isBase {
            guard let rate = Decimal(string: record.unitsOfBase, locale: Locale(identifier: "en_US_POSIX")) else { continue }
            try? table.setRate(rate, for: CurrencyCode(record.currencyCode), at: record.updatedAt)
        }
        return table
    }

    /// Runs a mutation and saves, mapping any failure to a `RepositoryError`.
    private func perform(_ work: () throws -> Void) throws(RepositoryError) {
        do {
            try work()
            try modelContext.save()
        } catch let error as RepositoryError {
            modelContext.rollback()
            throw error
        } catch {
            modelContext.rollback()
            throw .storage(error.localizedDescription)
        }
    }
}
