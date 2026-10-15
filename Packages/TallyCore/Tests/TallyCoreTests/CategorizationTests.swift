import Foundation
import Testing
@testable import TallyCore

@Suite("Rule-based categorisation")
struct CategorizationTests {
    @Test("Normalises processor prefixes, store numbers and case", arguments: [
        ("SQ *BLUE BOTTLE COFFEE #1042", "blue bottle coffee"),
        ("TST* Joe's Pizza 0042", "joes pizza"),
        ("UBER   *TRIP", "uber trip"),
        ("Pastéis de Belém", "pasteis de belem"),
    ])
    func normalise(raw: String, expected: String) {
        #expect(PayeeNormalizer.normalize(raw) == expected)
    }

    @Test("A learned correction beats the shipped keyword list")
    func learnedBeatsBuiltIn() throws {
        let rule = try #require(CategoryRule.learned(fromCorrectionOf: "AMAZON MKTPL*2K4 Seattle", to: .groceries))
        #expect(rule.keyword == "amazon mktpl seattle")
        let categorizer = RuleBasedCategorizer(learnedRules: [CategoryRule(keyword: "amazon", category: .groceries, isLearned: true)])
        let suggestion = categorizer.suggest(payee: "Amazon.com order", amount: Fixture.usd(-20_00))
        #expect(suggestion?.category == .groceries)
        #expect(suggestion?.source == .rule(keyword: "amazon", learned: true))
        #expect(suggestion?.confidence == 99)
    }

    @Test("The most specific keyword wins")
    func longestKeyword() {
        let categorizer = RuleBasedCategorizer(learnedRules: [])
        #expect(categorizer.suggest(payee: "UBER EATS 8KQ", amount: Fixture.usd(-30_00))?.category == .dining)
        #expect(categorizer.suggest(payee: "UBER TRIP", amount: Fixture.usd(-12_00))?.category == .transport)
    }

    @Test("Keywords match whole words only")
    func wholeWords() {
        let categorizer = RuleBasedCategorizer(learnedRules: [])
        #expect(categorizer.suggest(payee: "Tuberose Florist", amount: Fixture.usd(-25_00)) == nil)
        #expect(!PayeeNormalizer.payee("tuberose florist", contains: "uber"))
    }

    @Test("Unknown inflows default to income, unknown outflows to no suggestion")
    func unknownPayees() {
        let categorizer = RuleBasedCategorizer(learnedRules: [])
        #expect(categorizer.suggest(payee: "ACME Ltd", amount: Fixture.usd(300_00))?.category == .income)
        #expect(categorizer.suggest(payee: "ACME Ltd", amount: Fixture.usd(-300_00)) == nil)
    }

    @Test("Category vocabulary maps everyday words to category sets")
    func vocabulary() {
        #expect(CategoryVocabulary.categories(for: "food") == [.groceries, .dining])
        #expect(CategoryVocabulary.categories(for: "Dining") == [.dining])
        #expect(CategoryVocabulary.categories(for: "all") == nil)
        #expect(CategoryVocabulary.label(for: [.groceries, .dining]) == "food")
    }
}

@Suite("Entitlements")
struct EntitlementTests {
    let policy = EntitlementPolicy(plusProductIDs: ["plus.monthly", "plus.yearly"])
    let now = Fixture.date(2026, 10, 15)

    @Test("An active Plus subscription unlocks Plus")
    func active() {
        let record = PurchaseRecord(productID: "plus.monthly", purchaseDate: Fixture.date(2026, 10, 1), expirationDate: Fixture.date(2026, 11, 1))
        #expect(policy.tier(for: [record], now: now) == .plus)
    }

    @Test("Expired, revoked, upgraded or foreign purchases do not", arguments: [
        PurchaseRecord(productID: "plus.monthly", purchaseDate: Fixture.date(2026, 8, 1), expirationDate: Fixture.date(2026, 9, 1)),
        PurchaseRecord(productID: "plus.yearly", purchaseDate: Fixture.date(2026, 10, 1), expirationDate: Fixture.date(2027, 10, 1),
                       revocationDate: Fixture.date(2026, 10, 5)),
        PurchaseRecord(productID: "plus.monthly", purchaseDate: Fixture.date(2026, 10, 1), expirationDate: Fixture.date(2026, 11, 1),
                       isUpgraded: true),
        PurchaseRecord(productID: "tip.jar", purchaseDate: Fixture.date(2026, 10, 1), expirationDate: nil),
    ])
    func inactive(record: PurchaseRecord) {
        #expect(policy.tier(for: [record], now: now) == .free)
    }

    @Test("Free tier gets three budgets and no Plus features")
    func freeLimits() {
        #expect(policy.allows(.unlimitedBudgets, tier: .free, existingBudgets: 2))
        #expect(!policy.allows(.unlimitedBudgets, tier: .free, existingBudgets: 3))
        #expect(!policy.allows(.askTally, tier: .free))
        #expect(!policy.allows(.csvImport, tier: .free))
        #expect(PlusFeature.allCases.allSatisfy { policy.allows($0, tier: .plus, existingBudgets: 50) })
    }
}

@Suite("Demo ledger")
struct DemoLedgerTests {
    let calendar = Fixture.calendar()
    let now = Fixture.date(2026, 10, 15)

    @Test("Is deterministic for a given date and seed")
    func deterministic() {
        let first = DemoLedger(now: now, calendar: calendar).make()
        let second = DemoLedger(now: now, calendar: calendar).make()
        #expect(first.transactions.map(\.amount) == second.transactions.map(\.amount))
        #expect(first.transactions.map(\.payee) == second.transactions.map(\.payee))
    }

    @Test("Covers three accounts, two currencies and six months, never the future")
    func shape() throws {
        let data = DemoLedger(now: now, calendar: calendar).make()
        #expect(data.accounts.count == 3)
        #expect(Set(data.transactions.map(\.amount.currency)) == [.usd, .eur])
        let months = Set(data.transactions.map { calendar.dateComponents([.year, .month], from: $0.date) })
        #expect(months.count == 6)
        #expect(data.transactions.allSatisfy { $0.date <= now })
        #expect(data.transactions.contains { $0.categorization == .uncategorized })
        let engine = try LedgerQueryEngine(data: data, calendar: calendar, now: now)
        let september = try #require(DateRange.month(year: 2026, month: 9, calendar: calendar))
        #expect(engine.spending(in: september).total.isPositive)
    }
}
