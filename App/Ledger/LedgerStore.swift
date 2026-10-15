import Foundation
import Observation
import OSLog
import TallyCore
import TallyIntelligence

/// Told about every committed change, so widgets, Spotlight and budget alerts
/// stay in sync without the store knowing about any of them.
@MainActor
protocol LedgerChangeObserving {
    func ledgerDidChange(_ engine: LedgerQueryEngine) async
}

/// The app's single source of truth: the latest `LedgerData`, the query engine
/// built over it, and the only path for writes back to the repository.
@MainActor
@Observable
final class LedgerStore {
    private(set) var data: LedgerData = .empty()
    private(set) var engine: LedgerQueryEngine?
    private(set) var isLoaded = false
    private(set) var errorMessage: String?

    let calendar: Calendar
    @ObservationIgnored private let repository: any LedgerRepository
    @ObservationIgnored private let observers: [any LedgerChangeObserving]
    @ObservationIgnored private let now: @Sendable () -> Date

    init(
        repository: any LedgerRepository,
        calendar: Calendar,
        observers: [any LedgerChangeObserving],
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.repository = repository
        self.calendar = calendar
        self.observers = observers
        self.now = now
    }

    // MARK: Reading

    var accounts: [Account] { data.accounts }
    var baseCurrency: CurrencyCode { data.baseCurrency }

    func account(id: UUID) -> Account? {
        data.accounts.first { $0.id == id }
    }

    var pendingReview: [LedgerTransaction] {
        data.transactions.filter { $0.categorization == .uncategorized }
    }

    // MARK: Loading

    /// Loads, posts any recurring transactions that have come due, and rebuilds the engine.
    func load() async {
        await perform { [repository, calendar, now] in
            let current = try await repository.load()
            let due = RecurrenceMaterializer(calendar: calendar).dueTransactions(in: current, through: now())
            if !due.isEmpty { try await repository.upsert(due) }
        }
    }

    func reload() async {
        guard isLoaded else { return }
        await refresh(notify: false)
    }

    func seedDemoData() async {
        let demo = DemoLedger(now: now(), calendar: calendar).make()
        await perform { [repository] in try await repository.replaceAll(with: demo) }
    }

    // MARK: Writing

    func save(_ transaction: LedgerTransaction) async {
        await save([transaction])
    }

    func save(_ transactions: [LedgerTransaction]) async {
        guard !transactions.isEmpty else { return }
        await perform { [repository] in try await repository.upsert(transactions) }
    }

    func delete(_ transaction: LedgerTransaction) async {
        await perform { [repository] in try await repository.deleteTransaction(id: transaction.id) }
    }

    /// Re-files a transaction and, if asked, remembers the payee so future
    /// imports land in the same place.
    func recategorize(_ transaction: LedgerTransaction, as category: TransactionCategory, learn: Bool) async {
        var updated = transaction
        updated.category = category
        updated.categorization = .manual
        let rule = learn ? CategoryRule.learned(fromCorrectionOf: transaction.payee, to: category, at: now()) : nil
        await perform { [repository, updated] in
            try await repository.upsert(updated)
            if let rule { try await repository.upsert(rule) }
        }
    }

    func save(_ budget: Budget) async {
        await perform { [repository] in try await repository.upsert(budget) }
    }

    func delete(_ budget: Budget) async {
        await perform { [repository] in try await repository.deleteBudget(id: budget.id) }
    }

    func save(_ recurring: RecurringTransaction) async {
        await perform { [repository] in try await repository.upsert(recurring) }
        await load()
    }

    func deleteRule(_ rule: CategoryRule) async {
        await perform { [repository] in try await repository.deleteRule(keyword: rule.keyword) }
    }

    func save(_ rates: ExchangeRateTable) async {
        await perform { [repository] in try await repository.save(rates) }
    }

    /// Saves imported rows to `account`, categorising each with `categorizer`.
    func importRows(_ rows: [ImportedRow], into account: Account, categorizer: any TransactionCategorizing) async -> Int {
        var transactions: [LedgerTransaction] = []
        for row in rows {
            let amount = (try? data.rates.convert(row.amount, to: account.currency)) ?? row.amount
            let suggestion = await categorizer.suggest(payee: row.payee, amount: amount, notes: row.notes)
            transactions.append(LedgerTransaction(
                accountID: account.id,
                payee: row.payee,
                amount: amount,
                category: suggestion?.category ?? .other,
                categorization: suggestion?.source ?? .uncategorized,
                date: row.date,
                notes: row.notes,
                tags: ["imported"]
            ))
        }
        await save(transactions)
        return transactions.count
    }

    // MARK: Private

    private func perform(_ work: @escaping @Sendable () async throws -> Void) async {
        do {
            try await work()
            errorMessage = nil
        } catch {
            errorMessage = (error as? RepositoryError).map(Self.describe) ?? error.localizedDescription
            Logger.ledger.error("Ledger write failed: \(String(describing: error), privacy: .public)")
        }
        await refresh(notify: true)
    }

    private func refresh(notify: Bool) async {
        do {
            let latest = try await repository.load()
            let engine = try LedgerQueryEngine(data: latest, calendar: calendar, now: now())
            data = latest
            self.engine = engine
            isLoaded = true
            if notify {
                for observer in observers { await observer.ledgerDidChange(engine) }
            }
        } catch {
            errorMessage = (error as? FXError).map(Self.describe) ?? error.localizedDescription
            isLoaded = true
        }
    }

    private static func describe(_ error: RepositoryError) -> String {
        switch error {
        case .notFound: "That item no longer exists."
        case .storage(let detail): "Couldn't save: \(detail)"
        }
    }

    private static func describe(_ error: FXError) -> String {
        switch error {
        case .missingRate(let code): "Add an exchange rate for \(code.rawValue) in Settings to include it in totals."
        case .invalidRate(let code): "The exchange rate for \(code.rawValue) must be greater than zero."
        case .money: "An amount is too large to convert."
        }
    }
}
