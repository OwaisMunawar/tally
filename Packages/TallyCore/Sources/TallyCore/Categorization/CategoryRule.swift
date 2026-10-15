import Foundation

/// "Payees containing `keyword` belong in `category`."
public struct CategoryRule: Identifiable, Hashable, Sendable, Codable {
    public var keyword: String
    public var category: TransactionCategory
    /// Learned from the user's own correction, as opposed to shipped with the app.
    public var isLearned: Bool
    public var createdAt: Date

    public var id: String { keyword }

    public init(keyword: String, category: TransactionCategory, isLearned: Bool, createdAt: Date = .now) {
        self.keyword = PayeeNormalizer.normalize(keyword)
        self.category = category
        self.isLearned = isLearned
        self.createdAt = createdAt
    }

    /// The rule to remember when the user moves `payee` into `category`.
    public static func learned(fromCorrectionOf payee: String, to category: TransactionCategory, at date: Date = .now) -> CategoryRule? {
        let keyword = PayeeNormalizer.ruleKeyword(for: payee)
        guard keyword.count >= 2 else { return nil }
        return CategoryRule(keyword: keyword, category: category, isLearned: true, createdAt: date)
    }
}
