import Foundation
import Testing
import TallyCore
@testable import TallyData

@Suite("SwiftData repository")
struct SwiftDataLedgerRepositoryTests {
    private func makeRepository() throws -> SwiftDataLedgerRepository {
        SwiftDataLedgerRepository(modelContainer: try TallyStore.makeContainer(location: .inMemory))
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York") ?? .gmt
        return calendar
    }

    @Test("Round-trips a whole demo ledger without losing a minor unit")
    func roundTrip() async throws {
        let repository = try makeRepository()
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 15, hour: 12)))
        let demo = DemoLedger(now: now, calendar: calendar).make()
        try await repository.replaceAll(with: demo)

        let loaded = try await repository.load()
        #expect(loaded.accounts == demo.accounts.sorted { $0.sortOrder < $1.sortOrder })
        #expect(Set(loaded.transactions) == Set(demo.transactions))
        #expect(Set(loaded.budgets) == Set(demo.budgets))
        #expect(Set(loaded.recurring) == Set(demo.recurring))
        #expect(loaded.rates == demo.rates)
    }

    @Test("Upsert updates in place and preserves categorisation provenance")
    func upsertUpdates() async throws {
        let repository = try makeRepository()
        var transaction = LedgerTransaction(
            accountID: UUID(), payee: "SQ *RITUAL", amount: Money(minorUnits: -6_25, currency: .usd),
            category: .other, categorization: .uncategorized, date: .now
        )
        try await repository.upsert(transaction)
        transaction.category = .dining
        transaction.categorization = .model(confidence: 87)
        try await repository.upsert(transaction)

        let stored = try await repository.load().transactions
        #expect(stored.count == 1)
        #expect(stored.first?.categorization == .model(confidence: 87))
        #expect(stored.first?.category == .dining)
    }

    @Test("Learned rules are keyed by keyword and can be removed")
    func rules() async throws {
        let repository = try makeRepository()
        let rule = CategoryRule(keyword: "ritual roasters", category: .dining, isLearned: true)
        try await repository.upsert(rule)
        try await repository.upsert(CategoryRule(keyword: "ritual roasters", category: .groceries, isLearned: true))
        #expect(try await repository.load().rules.map(\.category) == [.groceries])
        try await repository.deleteRule(keyword: rule.keyword)
        #expect(try await repository.load().rules.isEmpty)
    }

    @Test("Deleting something missing is a typed not-found error")
    func deleteMissing() async throws {
        let repository = try makeRepository()
        let id = UUID()
        await #expect(throws: RepositoryError.notFound(id)) {
            try await repository.deleteTransaction(id: id)
        }
    }

    @Test("Exchange rates survive storage as exact decimals")
    func exactRates() async throws {
        let repository = try makeRepository()
        let rate = try #require(Decimal(string: "0.006712345678"))
        var table = ExchangeRateTable.baseOnly(.usd)
        try table.setRate(rate, for: .jpy)
        try await repository.save(table)
        #expect(try await repository.load().rates.rate(for: .jpy) == rate)
    }
}
