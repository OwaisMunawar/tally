import Foundation

/// Parses the amount formats banks actually export into `Decimal`, never `Double`.
///
/// Handles currency symbols and codes, thousands separators, a comma decimal
/// separator, accounting negatives like `(45.00)`, and trailing minus or
/// `CR`/`DR` markers.
public struct AmountParser: Sendable {
    public enum DecimalSeparator: String, CaseIterable, Sendable, Codable {
        case period, comma

        var character: Character { self == .period ? "." : "," }
        var grouping: Character { self == .period ? "," : "." }
    }

    public let decimalSeparator: DecimalSeparator

    public init(decimalSeparator: DecimalSeparator = .period) {
        self.decimalSeparator = decimalSeparator
    }

    public func parse(_ raw: String) -> Decimal? {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !text.isEmpty else { return nil }
        var negative = false

        if text.hasPrefix("(") && text.hasSuffix(")") {
            negative = true
            text = String(text.dropFirst().dropLast())
        }
        if text.hasSuffix("DR") {
            negative = true
            text = String(text.dropLast(2))
        } else if text.hasSuffix("CR") {
            text = String(text.dropLast(2))
        }
        text = text.trimmingCharacters(in: .whitespaces)
        if text.hasSuffix("-") {
            negative.toggle()
            text = String(text.dropLast())
        }

        var digits = ""
        var sawDecimal = false
        for character in text {
            switch character {
            case "0"..."9":
                digits.append(character)
            case "-" where digits.isEmpty:
                negative.toggle()
            case "+" where digits.isEmpty:
                continue
            case decimalSeparator.character:
                guard !sawDecimal else { return nil }
                sawDecimal = true
                digits.append(".")
            case decimalSeparator.grouping, " ", "'", "\u{00A0}", "\u{202F}":
                continue
            case _ where character.isLetter || character.isCurrencySymbol:
                continue
            default:
                return nil
            }
        }
        guard digits.contains(where: \.isNumber), let value = Decimal(string: digits, locale: Locale(identifier: "en_US_POSIX")) else {
            return nil
        }
        return negative ? -value : value
    }
}

private extension Character {
    var isCurrencySymbol: Bool {
        unicodeScalars.allSatisfy { $0.properties.generalCategory == .currencySymbol }
    }
}
