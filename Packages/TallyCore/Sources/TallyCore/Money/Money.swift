import Foundation

public enum MoneyError: Error, Equatable, Sendable {
    case currencyMismatch(CurrencyCode, CurrencyCode)
    case overflow
    case invalidAllocation
}

/// An amount of a single currency stored as an integer count of minor units.
///
/// Money never touches `Double`. Amounts enter as `Decimal`, are rounded once
/// to the currency's precision with an explicit `RoundingPolicy`, and from then
/// on every sum is exact integer arithmetic with overflow checks.
public struct Money: Hashable, Sendable, Codable {
    public let minorUnits: Int64
    public let currency: CurrencyCode

    public init(minorUnits: Int64, currency: CurrencyCode) {
        self.minorUnits = minorUnits
        self.currency = currency
    }

    /// Creates money from a major-unit decimal such as `12.345`, rounding to
    /// the currency's minor unit with `rounding`.
    public init(_ amount: Decimal, currency: CurrencyCode, rounding: RoundingPolicy = .default) throws(MoneyError) {
        let scaled = rounding.round(amount * currency.minorUnitScale, scale: 0)
        guard scaled.magnitude <= Self.int64MaxDecimal else { throw .overflow }
        self.init(minorUnits: NSDecimalNumber(decimal: scaled).int64Value, currency: currency)
    }

    public static func zero(_ currency: CurrencyCode) -> Money {
        Money(minorUnits: 0, currency: currency)
    }

    /// The exact major-unit value, e.g. `1234` minor units of USD is `12.34`.
    public var amount: Decimal {
        Decimal(minorUnits) / currency.minorUnitScale
    }

    public var isZero: Bool { minorUnits == 0 }
    public var isNegative: Bool { minorUnits < 0 }
    public var isPositive: Bool { minorUnits > 0 }

    public var magnitude: Money {
        Money(minorUnits: minorUnits.magnitude > UInt64(Int64.max) ? .max : abs(minorUnits), currency: currency)
    }

    public var negated: Money {
        Money(minorUnits: minorUnits == .min ? .max : -minorUnits, currency: currency)
    }

    public func adding(_ other: Money) throws(MoneyError) -> Money {
        guard other.currency == currency else { throw .currencyMismatch(currency, other.currency) }
        let (sum, overflow) = minorUnits.addingReportingOverflow(other.minorUnits)
        guard !overflow else { throw .overflow }
        return Money(minorUnits: sum, currency: currency)
    }

    public func subtracting(_ other: Money) throws(MoneyError) -> Money {
        try adding(other.negated)
    }

    /// Scales by a decimal factor (a rate, a share, a percentage) and rounds once.
    public func multiplied(by factor: Decimal, rounding: RoundingPolicy = .default) throws(MoneyError) -> Money {
        try Money(amount * factor, currency: currency, rounding: rounding)
    }

    /// Splits into `parts` amounts that differ by at most one minor unit and
    /// always sum back to the original, so nothing is lost to rounding.
    public func allocated(into parts: Int) throws(MoneyError) -> [Money] {
        guard parts > 0 else { throw .invalidAllocation }
        let count = Int64(parts)
        let base = minorUnits / count
        let remainder = Int(minorUnits % count)
        let step: Int64 = remainder < 0 ? -1 : 1
        return (0..<parts).map { index in
            Money(minorUnits: base + (index < abs(remainder) ? step : 0), currency: currency)
        }
    }

    public static func sum(_ values: some Sequence<Money>, currency: CurrencyCode) throws(MoneyError) -> Money {
        var total = Money.zero(currency)
        for value in values {
            total = try total.adding(value)
        }
        return total
    }

    private static let int64MaxDecimal = Decimal(Int64.max)
}

extension Money: Comparable {
    /// Ordering is only meaningful within a currency; mixed currencies order by code
    /// first so sorting a mixed array is at least deterministic.
    public static func < (lhs: Money, rhs: Money) -> Bool {
        if lhs.currency != rhs.currency { return lhs.currency < rhs.currency }
        return lhs.minorUnits < rhs.minorUnits
    }
}
