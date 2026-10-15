import Foundation
import Testing
@testable import TallyCore

@Suite("Ledger query engine")
struct QueryEngineTests {
    let calendar = Fixture.calendar()
    let september = DateRange.month(containing: Fixture.date(2026, 9, 1), calendar: Fixture.calendar())
    let august = DateRange.month(containing: Fixture.date(2026, 8, 1), calendar: Fixture.calendar())

    func engine(_ transactions: [LedgerTransaction], budgets: [Budget] = []) throws -> LedgerQueryEngine {
        let data = LedgerData(
            accounts: [Fixture.account, Fixture.euroAccount],
            transactions: transactions,
            budgets: budgets,
            rates: try Fixture.rates()
        )
        return try LedgerQueryEngine(data: data, calendar: calendar, now: Fixture.date(2026, 10, 15))
    }

    var sample: [LedgerTransaction] {
        [
            Fixture.spend("Trader Joe's", -80_00, .groceries, on: Fixture.date(2026, 9, 3)),
            Fixture.spend("Blue Bottle", -5_00, .dining, on: Fixture.date(2026, 9, 4)),
            Fixture.spend("Blue Bottle", -6_00, .dining, on: Fixture.date(2026, 9, 9)),
            Fixture.spend("Time Out Market", -20_00, .dining, on: Fixture.date(2026, 9, 12), account: Fixture.euroAccount),
            Fixture.spend("Trader Joe's", 10_00, .groceries, on: Fixture.date(2026, 9, 14)),
            Fixture.spend("Payroll", 5_000_00, .income, on: Fixture.date(2026, 9, 25)),
            Fixture.spend("Card autopay", -900_00, .transfer, on: Fixture.date(2026, 9, 20)),
            Fixture.spend("Sweetgreen", -15_00, .dining, on: Fixture.date(2026, 8, 10)),
            Fixture.spend("Whole Foods", -50_00, .groceries, on: Fixture.date(2026, 8, 11)),
        ]
    }

    @Test("Spend by category nets refunds and ignores income and transfers")
    func spendByCategory() throws {
        let totals = try engine(sample).spendByCategory(in: september)
        #expect(totals.map(\.category) == [.groceries, .dining])
        #expect(totals[0].total == Fixture.usd(70_00))
        #expect(totals[0].transactionCount == 2)
    }

    @Test("Foreign-currency spending is converted before summing")
    func multiCurrency() throws {
        // 5.00 + 6.00 USD plus 20.00 EUR at 1.10 = 22.00 USD.
        #expect(try engine(sample).spending(in: september, categories: [.dining]).total == Fixture.usd(33_00))
    }

    @Test("Compares two months with difference and percent change")
    func compareRanges() throws {
        let food = CategoryVocabulary.categories(for: "food")
        let comparison = try engine(sample).compare(september, with: august, categories: food)
        #expect(comparison.first.total == Fixture.usd(103_00))
        #expect(comparison.second.total == Fixture.usd(65_00))
        #expect(comparison.difference == Fixture.usd(38_00))
        #expect(comparison.percentChange == Fixture.decimal("58.5"))
    }

    @Test("Percent change is nil rather than infinite when the baseline is zero")
    func compareAgainstNothing() throws {
        let july = DateRange.month(containing: Fixture.date(2026, 7, 1), calendar: calendar)
        #expect(try engine(sample).compare(september, with: july).percentChange == nil)
    }

    @Test("Top payees group differently written descriptors of one merchant")
    func topPayees() throws {
        var transactions = sample
        transactions.append(Fixture.spend("SQ *BLUE BOTTLE #22", -4_00, .dining, on: Fixture.date(2026, 9, 15)))
        let payees = try engine(transactions).topPayees(in: september, limit: 2)
        #expect(payees.map(\.total) == [Fixture.usd(70_00), Fixture.usd(22_00)])
        let all = try engine(transactions).topPayees(in: september, limit: 10)
        #expect(all.first { $0.payee.contains("Blue") }?.transactionCount == 3)
    }

    @Test("Finds transactions by text, category, range and limit, newest first")
    func find() throws {
        let engine = try engine(sample)
        let coffee = engine.find(TransactionSearch(text: "blue bottle"))
        #expect(coffee.map(\.amount) == [Fixture.usd(-6_00), Fixture.usd(-5_00)])
        let augustGroceries = engine.find(TransactionSearch(categories: [.groceries], range: august))
        #expect(augustGroceries.map(\.payee) == ["Whole Foods"])
        #expect(engine.find(TransactionSearch(limit: 3)).count == 3)
        #expect(engine.find(TransactionSearch(minimumMagnitude: Fixture.usd(100_00))).map(\.category) == [.income, .transfer])
    }

    @Test("Budget states move from on track to near limit to over")
    func budgetStates() throws {
        let budgets = [
            Budget(category: .groceries, monthlyLimit: Fixture.usd(200_00)),
            Budget(category: .dining, monthlyLimit: Fixture.usd(40_00)),
            Budget(category: .travel, monthlyLimit: Fixture.usd(30_00)),
        ]
        let statuses = try engine(sample, budgets: budgets).budgetStatuses(in: september)
        let byCategory = Dictionary(uniqueKeysWithValues: statuses.map { ($0.budget.category, $0) })
        #expect(byCategory[.groceries]?.state == .onTrack)
        #expect(byCategory[.dining]?.state == .nearLimit)
        #expect(byCategory[.dining]?.remaining == Fixture.usd(7_00))
        #expect(byCategory[.travel]?.state == .onTrack)

        let tight = [Budget(category: .dining, monthlyLimit: Fixture.usd(30_00))]
        let over = try #require(engine(sample, budgets: tight).budgetStatuses(in: september).first)
        #expect(over.state == .over)
        #expect(over.remaining == Fixture.usd(-3_00))
    }

    @Test("Monthly cash flow excludes transfers")
    func cashFlow() throws {
        let points = try engine(sample).monthlyCashFlow(in: DateRange(start: august.start, end: september.end))
        #expect(points.count == 2)
        #expect(points[1].inflow == Fixture.usd(5_010_00))
        #expect(points[1].outflow == Fixture.usd(113_00))
        #expect(points[1].net == Fixture.usd(4_897_00))
    }

    @Test("Balances stay in account currency; net worth is in base")
    func balances() throws {
        let engine = try engine(sample)
        #expect(engine.balance(of: Fixture.euroAccount) == Fixture.eur(-20_00))
        // 3,954.00 USD in checking, less 20.00 EUR (22.00 USD) in cash.
        #expect(engine.netWorth == Fixture.usd(3_932_00))
    }

    @Test("An unknown currency fails loudly at load instead of silently skewing totals")
    func missingRate() {
        let yen = Account(name: "Tokyo", kind: .cash, currency: .jpy)
        let data = LedgerData(accounts: [yen], transactions: [Fixture.spend("Ramen", -1200, .dining, on: Fixture.date(2026, 9, 1), account: yen)],
                              rates: .baseOnly(.usd))
        #expect(throws: FXError.missingRate(.jpy)) {
            try LedgerQueryEngine(data: data, calendar: calendar, now: .now)
        }
    }
}

@Suite("Budget alerts")
struct BudgetAlertPolicyTests {
    let policy = BudgetAlertPolicy(calendar: Fixture.calendar())
    let october = DateRange.month(containing: Fixture.date(2026, 10, 1), calendar: Fixture.calendar())

    func status(_ category: TransactionCategory, spent: Int64, limit: Int64) -> BudgetStatus {
        BudgetStatus(budget: Budget(category: category, monthlyLimit: Fixture.usd(limit)), spent: Fixture.usd(spent))
    }

    @Test("Alerts once per category per month")
    func oncePerMonth() {
        let statuses = [status(.dining, spent: 330_00, limit: 320_00), status(.groceries, spent: 100_00, limit: 600_00)]
        let first = policy.newlyExceeded(statuses, month: october, alreadySent: [])
        #expect(first.map(\.budget.category) == [.dining])
        let sent = Set(first.map { policy.key(for: $0, month: october) })
        #expect(sent == ["2026-10:dining"])
        #expect(policy.newlyExceeded(statuses, month: october, alreadySent: sent).isEmpty)
    }

    @Test("Old months are pruned from the sent ledger")
    func pruning() {
        #expect(policy.pruned(["2026-09:dining", "2026-10:travel"], keeping: october) == ["2026-10:travel"])
    }
}
