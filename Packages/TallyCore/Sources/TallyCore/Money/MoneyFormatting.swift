import Foundation

public extension Money {
    /// Localised currency string, e.g. `$1,234.50` or `1.234,50 €`.
    func formatted(locale: Locale = .autoupdatingCurrent) -> String {
        amount.formatted(
            .currency(code: currency.rawValue)
                .locale(locale)
                .precision(.fractionLength(currency.minorUnitDigits))
        )
    }

    /// Whole-unit string for chart axes and tight layouts, e.g. `$1,235`.
    func formattedWhole(locale: Locale = .autoupdatingCurrent) -> String {
        amount.formatted(
            .currency(code: currency.rawValue)
                .locale(locale)
                .precision(.fractionLength(0))
        )
    }

    /// Lossy conversion for drawing only. Charts need a `Double`; arithmetic never does.
    var chartValue: Double {
        NSDecimalNumber(decimal: amount).doubleValue
    }
}
