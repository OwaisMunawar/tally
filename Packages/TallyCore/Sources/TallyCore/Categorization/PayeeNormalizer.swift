import Foundation

/// Reduces raw bank descriptors to a stable key.
///
/// "SQ *BLUE BOTTLE COFFEE #1042 OAKLAND" and "Blue Bottle Coffee" should learn
/// and match the same rule, so processor prefixes, store numbers and reference
/// codes are stripped before comparison.
public enum PayeeNormalizer {
    private static let processorPrefixes = [
        "sq *", "sq*", "tst*", "tst *", "paypal *", "pp*", "sp *", "sp*", "pos ", "dd ", "card purchase ", "debit ",
    ]

    public static func normalize(_ payee: String) -> String {
        var text = payee.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
        for prefix in processorPrefixes where text.hasPrefix(prefix) {
            text.removeFirst(prefix.count)
            break
        }
        let words = text
            .split { !$0.isLetter && $0 != "&" && $0 != "'" }
            .map { $0.replacingOccurrences(of: "'", with: "") }
            .filter { !$0.isEmpty }
        return words.joined(separator: " ")
    }

    /// The rule keyword learned from a correction: the first three meaningful
    /// words, which is specific enough to name a merchant without capturing a city.
    public static func ruleKeyword(for payee: String) -> String {
        normalize(payee)
            .split(separator: " ")
            .filter { $0.count > 1 || $0 == "&" }
            .prefix(3)
            .joined(separator: " ")
    }

    /// Whole-word containment, so the keyword "uber" matches "uber trip" but not "tuberose".
    public static func payee(_ normalizedPayee: String, contains keyword: String) -> Bool {
        guard !keyword.isEmpty else { return false }
        let padded = " \(normalizedPayee) "
        return padded.contains(" \(keyword) ")
    }
}
