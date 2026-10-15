import Foundation

/// An ISO 4217 currency code.
///
/// Kept as a thin wrapper rather than `Locale.Currency` so it is `Codable`
/// as a plain string, and so the minor-unit exponent comes from a table we
/// control instead of whatever the current locale's number formatter reports.
public struct CurrencyCode: RawRepresentable, Hashable, Comparable, Sendable, Codable, ExpressibleByStringLiteral {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue.trimmingCharacters(in: .whitespaces).uppercased()
    }

    public init(_ code: String) {
        self.init(rawValue: code)
    }

    public init(stringLiteral value: String) {
        self.init(rawValue: value)
    }

    public init(from decoder: any Decoder) throws {
        self.init(rawValue: try decoder.singleValueContainer().decode(String.self))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    /// Number of digits after the decimal point in the currency's minor unit.
    public var minorUnitDigits: Int {
        Self.exponents[rawValue] ?? 2
    }

    /// `10^minorUnitDigits` as a `Decimal`, the factor between major and minor units.
    public var minorUnitScale: Decimal {
        Decimal(sign: .plus, exponent: minorUnitDigits, significand: 1)
    }

    public var isValid: Bool {
        rawValue.count == 3 && rawValue.allSatisfy { $0.isASCII && $0.isUppercase }
    }

    public static func < (lhs: CurrencyCode, rhs: CurrencyCode) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    // Only the currencies whose exponent differs from 2 need listing.
    private static let exponents: [String: Int] = [
        "BHD": 3, "CLP": 0, "IQD": 3, "ISK": 0, "JOD": 3, "JPY": 0, "KRW": 0,
        "KWD": 3, "LYD": 3, "OMR": 3, "PYG": 0, "TND": 3, "UGX": 0, "VND": 0,
    ]
}

public extension CurrencyCode {
    static let usd: CurrencyCode = "USD"
    static let eur: CurrencyCode = "EUR"
    static let gbp: CurrencyCode = "GBP"
    static let jpy: CurrencyCode = "JPY"
    static let kwd: CurrencyCode = "KWD"
}

extension CurrencyCode: CustomStringConvertible {
    public var description: String { rawValue }
}
