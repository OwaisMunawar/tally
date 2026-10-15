import Foundation
import Testing
import TallyCore
import TallyIntelligence
@testable import Tally

@Suite("Ledger store")
@MainActor
struct LedgerStoreTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York") ?? .gmt
        return calendar
    }()

    func makeStore(_ data: LedgerData = .empty(), now: Date = .now) -> LedgerStore {
        LedgerStore(repository: InMemoryLedgerRepository(data), calendar: calendar, observers: [], now: { now })
    }

    @Test("Correcting a category with remember on learns a rule for the payee")
    func correctionLearnsRule() async throws {
        let account = Account(name: "Card", kind: .card, currency: .usd)
        let transaction = LedgerTransaction(
            accountID: account.id,
            payee: "SQ *RITUAL ROASTERS SF",
            amount: Money(minorUnits: -625, currency: .usd),
            category: .other,
            categorization: .uncategorized,
            date: .now
        )
        let store = makeStore(LedgerData(accounts: [account], transactions: [transaction], rates: .baseOnly(.usd)))
        await store.load()

        await store.recategorize(transaction, as: .dining, learn: true)

        #expect(store.data.rules.map(\.keyword) == ["ritual roasters sf"])
        #expect(store.data.transactions.first?.categorization == .manual)
        let next = RuleBasedCategorizer(learnedRules: store.data.rules)
            .suggest(payee: "RITUAL ROASTERS SF #2", amount: Money(minorUnits: -500, currency: .usd))
        #expect(next?.category == .dining)
    }

    @Test("Loading posts recurring transactions that came due while the app was closed")
    func materialisesRecurring() async throws {
        let account = Account(name: "Bank", kind: .bank, currency: .usd)
        let start = try #require(calendar.date(from: DateComponents(year: 2026, month: 7, day: 1, hour: 9)))
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 15, hour: 9)))
        let rent = RecurringTransaction(accountID: account.id, payee: "Rent", amount: Money(minorUnits: -2_000_00, currency: .usd),
                                        category: .housing, rule: .monthly, startDate: start)
        let store = makeStore(LedgerData(accounts: [account], recurring: [rent], rates: .baseOnly(.usd)), now: now)

        await store.load()
        #expect(store.data.transactions.count == 4)
        await store.load()
        #expect(store.data.transactions.count == 4)
    }

    @Test("CSV rows import into the account currency with categories")
    func importConvertsCurrency() async throws {
        let euros = Account(name: "Euro", kind: .cash, currency: .eur)
        var rates = ExchangeRateTable.baseOnly(.usd)
        try rates.setRate(2, for: .eur)
        let store = makeStore(LedgerData(accounts: [euros], rates: rates))
        await store.load()
        let row = ImportedRow(line: 2, date: .now, payee: "Uber Trip", amount: Money(minorUnits: -10_00, currency: .usd), notes: "")

        let rulesOnly = HybridCategorizer(rules: RuleBasedCategorizer(learnedRules: []), model: nil)
        let count = await store.importRows([row], into: euros, categorizer: rulesOnly)

        #expect(count == 1)
        #expect(store.data.transactions.first?.amount == Money(minorUnits: -5_00, currency: .eur))
        #expect(store.data.transactions.first?.category == .transport)
    }
}
