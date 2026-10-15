import Foundation

/// Six months of fictional but realistic finances for the `-demoData` launch
/// argument, previews and screenshots. Every merchant amount is drawn in minor
/// units from a seeded generator, so the ledger is identical on every run for a
/// given `now`.
public struct DemoLedger: Sendable {
    public let now: Date
    public let calendar: Calendar
    public let months: Int
    public let seed: UInt64

    public init(now: Date, calendar: Calendar, months: Int = 6, seed: UInt64 = 2026) {
        self.now = now
        self.calendar = calendar
        self.months = months
        self.seed = seed
    }

    public static let checkingID = UUID(uuidString: "6F1C2A10-0000-4000-8000-000000000001") ?? UUID()
    public static let cardID = UUID(uuidString: "6F1C2A10-0000-4000-8000-000000000002") ?? UUID()
    public static let travelCashID = UUID(uuidString: "6F1C2A10-0000-4000-8000-000000000003") ?? UUID()

    public func make() -> LedgerData {
        var rng = SeededGenerator(seed: seed)
        let accounts = [
            Account(id: Self.checkingID, name: "Everyday Checking", kind: .bank, currency: .usd,
                    openingBalance: usd(4_250_00), lastFour: "2210", sortOrder: 0),
            Account(id: Self.cardID, name: "Sapphire Card", kind: .card, currency: .usd,
                    openingBalance: usd(0), lastFour: "4417", sortOrder: 1),
            Account(id: Self.travelCashID, name: "Euro Travel Cash", kind: .cash, currency: .eur,
                    openingBalance: Money(minorUnits: 300_00, currency: .eur), sortOrder: 2),
        ]

        let currentMonth = DateRange.month(containing: now, calendar: calendar)
        let firstMonthStart = calendar.date(byAdding: .month, value: -(months - 1), to: currentMonth.start) ?? currentMonth.start
        let span = DateRange(start: firstMonthStart, end: currentMonth.end)

        let recurring = recurringTemplates(startingAt: firstMonthStart)
        var transactions = recurring.flatMap { template in
            template.dueTransactions(in: DateRange(start: firstMonthStart, end: now), existing: [], calendar: calendar)
        }
        for month in span.months(calendar: calendar) {
            transactions += everydaySpending(in: month, rng: &rng)
        }
        transactions += trip(rng: &rng)
        transactions += uncategorizedImports()
        transactions = transactions.filter { $0.date <= now }

        return LedgerData(
            accounts: accounts,
            transactions: transactions,
            budgets: budgets,
            recurring: recurring,
            rules: [],
            rates: rates
        )
    }

    // MARK: Pieces

    private var rates: ExchangeRateTable {
        var table = ExchangeRateTable.baseOnly(.usd, updatedAt: now)
        // Fixed, user-style rates: Tally never fetches them.
        try? table.setRate(Decimal(string: "1.08") ?? 1, for: .eur, at: now)
        try? table.setRate(Decimal(string: "1.27") ?? 1, for: .gbp, at: now)
        try? table.setRate(Decimal(string: "0.0067") ?? 1, for: .jpy, at: now)
        return table
    }

    private var budgets: [Budget] {
        [
            Budget(id: stableID(1), category: .groceries, monthlyLimit: usd(650_00)),
            Budget(id: stableID(2), category: .dining, monthlyLimit: usd(180_00)),
            Budget(id: stableID(3), category: .transport, monthlyLimit: usd(220_00)),
            Budget(id: stableID(4), category: .shopping, monthlyLimit: usd(300_00)),
            Budget(id: stableID(5), category: .entertainment, monthlyLimit: usd(120_00)),
        ]
    }

    private func recurringTemplates(startingAt start: Date) -> [RecurringTransaction] {
        func day(_ value: Int) -> Date {
            calendar.date(bySetting: .day, value: value, of: start).map { at(hour: 9, on: $0) } ?? start
        }
        return [
            RecurringTransaction(id: stableID(101), accountID: Self.checkingID, payee: "Northwind Labs Payroll",
                                 amount: usd(5_400_00), category: .income, rule: .monthly, startDate: day(25)),
            RecurringTransaction(id: stableID(102), accountID: Self.checkingID, payee: "Maple Court Apartments",
                                 amount: usd(-2_150_00), category: .housing, rule: .monthly, startDate: day(1)),
            RecurringTransaction(id: stableID(103), accountID: Self.cardID, payee: "Netflix",
                                 amount: usd(-15_49), category: .subscriptions, rule: .monthly, startDate: day(7)),
            RecurringTransaction(id: stableID(104), accountID: Self.cardID, payee: "Spotify",
                                 amount: usd(-11_99), category: .subscriptions, rule: .monthly, startDate: day(12)),
            RecurringTransaction(id: stableID(105), accountID: Self.cardID, payee: "Apple.com/Bill iCloud+",
                                 amount: usd(-2_99), category: .subscriptions, rule: .monthly, startDate: day(3)),
            RecurringTransaction(id: stableID(106), accountID: Self.checkingID, payee: "Peak Fitness Club",
                                 amount: usd(-49_00), category: .health, rule: .monthly, startDate: day(2)),
            RecurringTransaction(id: stableID(107), accountID: Self.checkingID, payee: "Sapphire Card Autopay",
                                 amount: usd(-1_100_00), category: .transfer, rule: .monthly, startDate: day(20)),
        ]
    }

    private struct Merchant {
        let payee: String
        let category: TransactionCategory
        let range: ClosedRange<Int64>
        let perMonth: ClosedRange<Int>
        let account: UUID
    }

    private var merchants: [Merchant] {
        [
            Merchant(payee: "Trader Joe's", category: .groceries, range: 38_00...96_00, perMonth: 4...5, account: Self.cardID),
            Merchant(payee: "Whole Foods Market", category: .groceries, range: 45_00...140_00, perMonth: 2...3, account: Self.cardID),
            Merchant(payee: "Blue Bottle Coffee", category: .dining, range: 4_75...9_50, perMonth: 6...9, account: Self.cardID),
            Merchant(payee: "Sweetgreen", category: .dining, range: 13_50...18_90, perMonth: 3...5, account: Self.cardID),
            Merchant(payee: "Joe's Pizza", category: .dining, range: 18_00...42_00, perMonth: 1...3, account: Self.cardID),
            Merchant(payee: "Uber Eats", category: .dining, range: 24_00...58_00, perMonth: 1...3, account: Self.cardID),
            Merchant(payee: "MTA OMNY", category: .transport, range: 2_90...2_90, perMonth: 14...20, account: Self.cardID),
            Merchant(payee: "Uber Trip", category: .transport, range: 11_00...34_00, perMonth: 2...4, account: Self.cardID),
            Merchant(payee: "Con Edison Electric", category: .utilities, range: 84_00...131_00, perMonth: 1...1, account: Self.checkingID),
            Merchant(payee: "Verizon Mobile", category: .utilities, range: 65_00...65_00, perMonth: 1...1, account: Self.checkingID),
            Merchant(payee: "Amazon", category: .shopping, range: 12_00...89_00, perMonth: 2...4, account: Self.cardID),
            Merchant(payee: "Uniqlo", category: .shopping, range: 29_90...119_00, perMonth: 0...1, account: Self.cardID),
            Merchant(payee: "CVS Pharmacy", category: .health, range: 8_00...36_00, perMonth: 0...2, account: Self.cardID),
            Merchant(payee: "AMC Theatres", category: .entertainment, range: 16_00...38_00, perMonth: 0...2, account: Self.cardID),
        ]
    }

    private func everydaySpending(in month: DateRange, rng: inout SeededGenerator) -> [LedgerTransaction] {
        let daysInMonth = calendar.range(of: .day, in: .month, for: month.start)?.count ?? 28
        // September runs hot on dining so "September vs August" has a story to tell.
        let isSeptember = calendar.component(.month, from: month.start) == 9
        var result: [LedgerTransaction] = []
        for merchant in merchants {
            var count = Int.random(in: merchant.perMonth, using: &rng)
            if isSeptember && merchant.category == .dining { count += 3 }
            for _ in 0..<count {
                let day = Int.random(in: 1...daysInMonth, using: &rng)
                let hour = Int.random(in: 8...21, using: &rng)
                guard let date = calendar.date(byAdding: DateComponents(day: day - 1, hour: hour), to: month.start) else { continue }
                result.append(LedgerTransaction(
                    accountID: merchant.account,
                    payee: merchant.payee,
                    amount: usd(-Int64.random(in: merchant.range, using: &rng)),
                    category: merchant.category,
                    categorization: .rule(keyword: PayeeNormalizer.ruleKeyword(for: merchant.payee), learned: false),
                    date: date
                ))
            }
        }
        return result
    }

    /// A long weekend in Lisbon two months back: a dollar flight and hotel on the
    /// card, and euro cash on the ground, so multi-currency maths shows up in totals.
    private func trip(rng: inout SeededGenerator) -> [LedgerTransaction] {
        let tripMonth = calendar.date(byAdding: .month, value: -2, to: DateRange.month(containing: now, calendar: calendar).start) ?? now
        func on(_ day: Int, _ hour: Int = 12) -> Date {
            calendar.date(byAdding: DateComponents(day: day - 1, hour: hour), to: tripMonth) ?? tripMonth
        }
        var result = [
            LedgerTransaction(accountID: Self.cardID, payee: "TAP Air Portugal", amount: usd(-642_80), category: .travel,
                              date: on(2, 10), notes: "JFK to LIS return", tags: ["lisbon"]),
            LedgerTransaction(accountID: Self.cardID, payee: "Hotel Alfama Lisboa", amount: usd(-486_00), category: .travel,
                              date: on(14, 15), tags: ["lisbon"]),
        ]
        let euroSpends = [
            Merchant(payee: "Pastéis de Belém", category: .dining, range: 6_00...14_00, perMonth: 1...1, account: Self.travelCashID),
            Merchant(payee: "Time Out Market", category: .dining, range: 22_00...48_00, perMonth: 1...1, account: Self.travelCashID),
            Merchant(payee: "Bolt Lisboa", category: .transport, range: 7_00...16_00, perMonth: 1...1, account: Self.travelCashID),
            Merchant(payee: "Museu Calouste Gulbenkian", category: .entertainment, range: 10_00...10_00, perMonth: 1...1, account: Self.travelCashID),
            Merchant(payee: "Pingo Doce", category: .groceries, range: 9_00...26_00, perMonth: 1...1, account: Self.travelCashID),
        ]
        for (offset, spend) in euroSpends.enumerated() {
            result.append(LedgerTransaction(
                accountID: spend.account,
                payee: spend.payee,
                amount: Money(minorUnits: -Int64.random(in: spend.range, using: &rng), currency: .eur),
                category: spend.category,
                categorization: .manual,
                date: on(14 + offset % 3, 11 + offset),
                tags: ["lisbon"]
            ))
        }
        return result
    }

    /// Fresh card lines with no category yet, as if just imported, so the
    /// auto-categoriser has real work to do on first launch.
    private func uncategorizedImports() -> [LedgerTransaction] {
        let lines: [(String, Int64)] = [
            ("SQ *RITUAL ROASTERS SF", -6_25),
            ("WALGREENS #4471", -18_42),
            ("TST* LUCKY DUMPLING HOUSE", -21_60),
            ("STEAMGAMES.COM 4259522", -29_99),
            ("SHELL OIL 57444", -46_10),
        ]
        return lines.enumerated().map { index, line in
            let date = calendar.date(byAdding: .hour, value: -(index * 9 + 3), to: now) ?? now
            return LedgerTransaction(
                id: stableID(900 + index),
                accountID: Self.cardID,
                payee: line.0,
                amount: usd(line.1),
                category: .other,
                categorization: .uncategorized,
                date: date,
                tags: ["imported"]
            )
        }
    }

    // MARK: Helpers

    private func usd(_ minorUnits: Int64) -> Money {
        Money(minorUnits: minorUnits, currency: .usd)
    }

    private func at(hour: Int, on date: Date) -> Date {
        calendar.date(bySettingHour: hour, minute: 0, second: 0, of: date) ?? date
    }

    private func stableID(_ value: Int) -> UUID {
        UUID(uuidString: String(format: "6F1C2A10-0000-4000-8000-%012d", value)) ?? UUID()
    }
}
