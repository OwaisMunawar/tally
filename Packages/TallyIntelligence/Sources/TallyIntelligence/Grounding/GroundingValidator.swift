import Foundation
import TallyCore

/// Which figures in an answer could be traced back to tool output.
public struct GroundingReport: Hashable, Sendable {
    /// Figures found verbatim (or as a coarser rounding) in tool output or the question.
    public let verified: [String]
    /// Figures that appear in the answer but in no tool result.
    public let unverified: [String]

    public var isGrounded: Bool { unverified.isEmpty }

    public init(verified: [String], unverified: [String]) {
        self.verified = verified
        self.unverified = unverified
    }
}

/// Checks that every number in a model answer came from a tool.
///
/// Small on-device models are good at language and bad at arithmetic, so Tally
/// never lets the model compute: tools return totals, differences and
/// percentages ready-made, and this validator rejects any figure that isn't
/// in their output. It is deliberately strict; a false "unverified" flag costs
/// a retry, a false "verified" would cost the user's trust.
public struct GroundingValidator: Sendable {
    public init() {}

    public func validate(answer: String, evidence: [String]) -> GroundingReport {
        let known = evidence.flatMap(Self.figures(in:))
        let exact = Set(known.map(\.value.magnitude))
        var verified: [String] = []
        var unverified: [String] = []
        for figure in Self.figures(in: answer) where !figure.isDatePart && !figure.isYear {
            if exact.contains(figure.value.magnitude) || Self.isCoarserRounding(figure, of: known) {
                verified.append(figure.text)
            } else {
                unverified.append(figure.text)
            }
        }
        return GroundingReport(verified: verified, unverified: unverified)
    }

    /// "$412" or "about $410"-style roundings of a tool's "$412.30" are fine;
    /// they lose precision but cannot invent a number.
    private static func isCoarserRounding(_ figure: Figure, of known: [Figure]) -> Bool {
        known.contains { source in
            guard figure.fractionDigits < source.fractionDigits else { return false }
            let rounded = RoundingPolicy.halfAwayFromZero.round(source.value.magnitude, scale: figure.fractionDigits)
            return rounded == figure.value.magnitude
        }
    }

    struct Figure: Hashable {
        let text: String
        let value: Decimal
        let fractionDigits: Int
        let hasCurrencyOrPercent: Bool
        let isDatePart: Bool

        /// Bare four-digit years are context, not claims about money.
        var isYear: Bool {
            !hasCurrencyOrPercent && fractionDigits == 0 && (1900...2100).contains(value)
        }
    }

    private static let monthWords = [
        "jan", "january", "feb", "february", "mar", "march", "apr", "april", "may", "jun", "june", "jul", "july",
        "aug", "august", "sep", "sept", "september", "oct", "october", "nov", "november", "dec", "december",
    ]

    static func figures(in text: String) -> [Figure] {
        let pattern = /(?<sign>[-+−]?)(?<currency>[$€£¥]?)\s?(?<number>\d{1,3}(?:,\d{3})+(?:\.\d+)?|\d+(?:\.\d+)?)(?<suffix>%|st\b|nd\b|rd\b|th\b)?/
        return text.matches(of: pattern).compactMap { match in
            let number = String(match.output.number).replacingOccurrences(of: ",", with: "")
            guard var value = Decimal(string: number, locale: Locale(identifier: "en_US_POSIX")) else { return nil }
            if !match.output.sign.isEmpty && match.output.sign != "+" { value = -value }
            let suffix = match.output.suffix.map(String.init) ?? ""
            let fraction = number.split(separator: ".").dropFirst().first?.count ?? 0
            let preceding = text[..<match.range.lowerBound].split(whereSeparator: { !$0.isLetter }).last.map { $0.lowercased() } ?? ""
            let isOrdinal = ["st", "nd", "rd", "th"].contains(suffix)
            return Figure(
                text: String(text[match.range]).trimmingCharacters(in: .whitespaces),
                value: value,
                fractionDigits: fraction,
                hasCurrencyOrPercent: !match.output.currency.isEmpty || suffix == "%",
                isDatePart: isOrdinal || (monthWords.contains(preceding) && match.output.currency.isEmpty && fraction == 0)
            )
        }
    }
}
