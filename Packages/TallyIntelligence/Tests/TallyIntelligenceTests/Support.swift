import Foundation
import TallyCore

enum Ledger {
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York") ?? .gmt
        return calendar
    }

    static func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12)) ?? .distantPast
    }

    static let checking = Account(name: "Checking", kind: .bank, currency: .usd)
    static let cash = Account(name: "Cash", kind: .cash, currency: .eur)

    static func usd(_ minor: Int64) -> Money { Money(minorUnits: minor, currency: .usd) }

    static func engine() throws -> LedgerQueryEngine {
        func spend(_ payee: String, _ minor: Int64, _ category: TransactionCategory, _ date: Date, account: Account = checking) -> LedgerTransaction {
            LedgerTransaction(accountID: account.id, payee: payee, amount: Money(minorUnits: minor, currency: account.currency),
                              category: category, date: date)
        }
        let transactions = [
            spend("Trader Joe's", -84_20, .groceries, date(2026, 9, 3)),
            spend("Blue Bottle Coffee", -6_50, .dining, date(2026, 9, 4)),
            spend("Sweetgreen", -16_40, .dining, date(2026, 9, 18)),
            spend("Time Out Market", -30_00, .dining, date(2026, 9, 20), account: cash),
            spend("Whole Foods Market", -61_75, .groceries, date(2026, 8, 9)),
            spend("Blue Bottle Coffee", -5_75, .dining, date(2026, 8, 12)),
            spend("Northwind Payroll", 5_400_00, .income, date(2026, 9, 25)),
        ]
        var rates = ExchangeRateTable.baseOnly(.usd)
        try rates.setRate(Decimal(string: "1.08") ?? 1, for: .eur)
        let data = LedgerData(
            accounts: [checking, cash],
            transactions: transactions,
            budgets: [Budget(category: .dining, monthlyLimit: usd(60_00)), Budget(category: .groceries, monthlyLimit: usd(400_00))],
            rates: rates
        )
        return try LedgerQueryEngine(data: data, calendar: calendar, now: date(2026, 10, 15))
    }
}
