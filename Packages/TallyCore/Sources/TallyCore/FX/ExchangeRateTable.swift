import Foundation

public enum FXError: Error, Equatable, Sendable {
    case missingRate(CurrencyCode)
    case invalidRate(CurrencyCode)
    case money(MoneyError)
}

/// User-maintained exchange rates, all quoted against one base currency.
///
/// Tally never fetches rates from the network, so the table is whatever the
/// user (or the demo seed) entered. Quoting every rate against the base keeps
/// cross conversions consistent: EUR to GBP always goes through the same two
/// numbers the user can see and edit.
public struct ExchangeRateTable: Hashable, Sendable, Codable {
    public let baseCurrency: CurrencyCode
    /// How many units of the base currency one unit of the key currency buys.
    public private(set) var unitsOfBase: [CurrencyCode: Decimal]
    public private(set) var updatedAt: Date

    public init(baseCurrency: CurrencyCode, rates: [CurrencyCode: Decimal], updatedAt: Date = .distantPast) throws(FXError) {
        self = .baseOnly(baseCurrency, updatedAt: updatedAt)
        for (code, rate) in rates where code != baseCurrency {
            try setRate(rate, for: code, at: updatedAt)
        }
    }

    private init(baseCurrency: CurrencyCode, updatedAt: Date) {
        self.baseCurrency = baseCurrency
        self.unitsOfBase = [baseCurrency: 1]
        self.updatedAt = updatedAt
    }

    /// A table that only knows its own base currency. Cannot fail.
    public static func baseOnly(_ baseCurrency: CurrencyCode, updatedAt: Date = .distantPast) -> ExchangeRateTable {
        ExchangeRateTable(baseCurrency: baseCurrency, updatedAt: updatedAt)
    }

    public var currencies: [CurrencyCode] {
        unitsOfBase.keys.sorted()
    }

    public func rate(for currency: CurrencyCode) -> Decimal? {
        unitsOfBase[currency]
    }

    public mutating func setRate(_ rate: Decimal, for currency: CurrencyCode, at date: Date = .now) throws(FXError) {
        guard currency != baseCurrency else { return }
        guard rate > 0, rate.isFinite else { throw .invalidRate(currency) }
        unitsOfBase[currency] = rate
        updatedAt = max(updatedAt, date)
    }

    public mutating func removeRate(for currency: CurrencyCode) {
        guard currency != baseCurrency else { return }
        unitsOfBase[currency] = nil
    }

    /// Converts with a single rounding step at the end, so a cross conversion
    /// is no less precise than a direct one.
    public func convert(_ money: Money, to target: CurrencyCode, rounding: RoundingPolicy = .default) throws(FXError) -> Money {
        if money.currency == target { return money }
        guard let sourceRate = unitsOfBase[money.currency] else { throw .missingRate(money.currency) }
        guard let targetRate = unitsOfBase[target] else { throw .missingRate(target) }
        do {
            return try Money(money.amount * sourceRate / targetRate, currency: target, rounding: rounding)
        } catch {
            throw .money(error)
        }
    }

    public func toBase(_ money: Money, rounding: RoundingPolicy = .default) throws(FXError) -> Money {
        try convert(money, to: baseCurrency, rounding: rounding)
    }
}
