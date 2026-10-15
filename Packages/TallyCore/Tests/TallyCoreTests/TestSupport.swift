import Foundation
@testable import TallyCore

enum Fixture {
    static let newYork = TimeZone(identifier: "America/New_York") ?? .gmt

    static func calendar(_ timeZone: TimeZone = newYork) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }

    static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 0, calendar: Calendar = calendar()) -> Date {
        guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)) else {
            preconditionFailure("Invalid fixture date \(year)-\(month)-\(day)")
        }
        return date
    }

    static func usd(_ minorUnits: Int64) -> Money {
        Money(minorUnits: minorUnits, currency: .usd)
    }

    static func eur(_ minorUnits: Int64) -> Money {
        Money(minorUnits: minorUnits, currency: .eur)
    }

    static func decimal(_ string: String) -> Decimal {
        guard let value = Decimal(string: string, locale: Locale(identifier: "en_US_POSIX")) else {
            preconditionFailure("Invalid decimal fixture \(string)")
        }
        return value
    }

    static let account = Account(name: "Checking", kind: .bank, currency: .usd)
    static let euroAccount = Account(name: "Euro Cash", kind: .cash, currency: .eur)

    static func rates() throws -> ExchangeRateTable {
        try ExchangeRateTable(baseCurrency: .usd, rates: [.eur: decimal("1.10"), .gbp: decimal("1.25")])
    }

    static func spend(
        _ payee: String,
        _ minorUnits: Int64,
        _ category: TransactionCategory,
        on date: Date,
        account: Account = account
    ) -> LedgerTransaction {
        LedgerTransaction(
            accountID: account.id,
            payee: payee,
            amount: Money(minorUnits: minorUnits, currency: account.currency),
            category: category,
            date: date
        )
    }
}
