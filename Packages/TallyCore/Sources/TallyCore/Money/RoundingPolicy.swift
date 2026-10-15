import Foundation

/// How a `Decimal` is brought to a currency's minor-unit precision.
///
/// The default is banker's rounding: it is unbiased, so converting thousands of
/// transactions between currencies does not drift the totals upward the way
/// half-up rounding does.
public enum RoundingPolicy: String, CaseIterable, Sendable, Codable {
    /// Round half to even (IEEE 754 / banker's rounding).
    case bankers
    /// Round half away from zero, which is what most receipts do.
    case halfAwayFromZero
    /// Drop extra digits, rounding toward zero.
    case towardZero

    public static let `default`: RoundingPolicy = .bankers

    /// Rounds `value` to `scale` digits after the decimal point.
    public func round(_ value: Decimal, scale: Int) -> Decimal {
        var input = value
        var result = Decimal()
        switch self {
        case .bankers:
            NSDecimalRound(&result, &input, scale, .bankers)
        case .halfAwayFromZero:
            NSDecimalRound(&result, &input, scale, .plain)
        case .towardZero:
            // Foundation's `.down` is a floor, so negatives need `.up` to move toward zero.
            NSDecimalRound(&result, &input, scale, value.sign == .minus ? .up : .down)
        }
        return result
    }
}
