import Foundation

public enum RepositoryError: Error, Equatable, Sendable {
    case notFound(UUID)
    case storage(String)
}

/// Persistence boundary. The app and widget talk to this protocol; SwiftData is
/// one implementation and `InMemoryLedgerRepository` is another for tests and previews.
public protocol LedgerRepository: Sendable {
    func load() async throws(RepositoryError) -> LedgerData
    func upsert(_ transactions: [LedgerTransaction]) async throws(RepositoryError)
    func deleteTransaction(id: UUID) async throws(RepositoryError)
    func upsert(_ account: Account) async throws(RepositoryError)
    func upsert(_ budget: Budget) async throws(RepositoryError)
    func deleteBudget(id: UUID) async throws(RepositoryError)
    func upsert(_ recurring: RecurringTransaction) async throws(RepositoryError)
    func upsert(_ rule: CategoryRule) async throws(RepositoryError)
    func deleteRule(keyword: String) async throws(RepositoryError)
    func save(_ rates: ExchangeRateTable) async throws(RepositoryError)
    func replaceAll(with data: LedgerData) async throws(RepositoryError)
}

public extension LedgerRepository {
    func upsert(_ transaction: LedgerTransaction) async throws(RepositoryError) {
        try await upsert([transaction])
    }
}

/// Posts any recurring transactions that have come due up to `now`.
public struct RecurrenceMaterializer: Sendable {
    public let calendar: Calendar

    public init(calendar: Calendar) {
        self.calendar = calendar
    }

    public func dueTransactions(in data: LedgerData, through now: Date) -> [LedgerTransaction] {
        data.recurring.flatMap { template in
            template.dueTransactions(
                in: DateRange(start: template.startDate, end: now),
                existing: data.transactions,
                calendar: calendar
            )
        }
    }
}
