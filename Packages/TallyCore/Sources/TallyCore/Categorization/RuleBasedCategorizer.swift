import Foundation

public struct CategorySuggestion: Hashable, Sendable {
    public let category: TransactionCategory
    public let source: CategorizationSource

    public init(category: TransactionCategory, source: CategorizationSource) {
        self.category = category
        self.source = source
    }

    /// Confidence on the same 0–100 scale the model reports, so the UI can
    /// render one badge regardless of where a suggestion came from.
    public var confidence: Int {
        switch source {
        case .manual: 100
        case .rule(_, let learned): learned ? 99 : 85
        case .model(let confidence): confidence
        case .uncategorized: 0
        }
    }
}

/// Deterministic categoriser: the user's learned rules first, then shipped keywords.
///
/// This is the floor the app stands on when Apple Intelligence is unavailable,
/// and it runs before the model when a learned rule exists, because a user's
/// explicit correction should always beat a guess.
public struct RuleBasedCategorizer: Sendable {
    public let learnedRules: [CategoryRule]
    public let builtInRules: [CategoryRule]

    public init(learnedRules: [CategoryRule], builtInRules: [CategoryRule] = RuleBasedCategorizer.defaultRules) {
        // Longest keyword first: "uber eats" must win over "uber".
        self.learnedRules = learnedRules.sorted(by: Self.specificity)
        self.builtInRules = builtInRules.sorted(by: Self.specificity)
    }

    /// The learned-rule match alone, used to short-circuit the model.
    public func learnedMatch(payee: String) -> CategorySuggestion? {
        match(PayeeNormalizer.normalize(payee), in: learnedRules)
    }

    /// A learned or shipped keyword match, without the sign-of-amount fallback.
    public func keywordMatch(payee: String) -> CategorySuggestion? {
        let normalized = PayeeNormalizer.normalize(payee)
        return match(normalized, in: learnedRules) ?? match(normalized, in: builtInRules)
    }

    public func suggest(payee: String, amount: Money) -> CategorySuggestion? {
        let normalized = PayeeNormalizer.normalize(payee)
        if let learned = match(normalized, in: learnedRules) { return learned }
        // A refund from a merchant still belongs to the merchant's category, so
        // keyword rules are checked before the sign of the amount.
        if let builtIn = match(normalized, in: builtInRules) { return builtIn }
        if amount.isPositive {
            return CategorySuggestion(category: .income, source: .rule(keyword: "inflow", learned: false))
        }
        return nil
    }

    private func match(_ normalizedPayee: String, in rules: [CategoryRule]) -> CategorySuggestion? {
        guard let rule = rules.first(where: { PayeeNormalizer.payee(normalizedPayee, contains: $0.keyword) }) else { return nil }
        return CategorySuggestion(category: rule.category, source: .rule(keyword: rule.keyword, learned: rule.isLearned))
    }

    private static func specificity(_ lhs: CategoryRule, _ rhs: CategoryRule) -> Bool {
        if lhs.keyword.count != rhs.keyword.count { return lhs.keyword.count > rhs.keyword.count }
        return lhs.keyword < rhs.keyword
    }

    public static let defaultRules: [CategoryRule] = {
        let table: [TransactionCategory: [String]] = [
            .groceries: ["whole foods", "trader joe's", "safeway", "kroger", "aldi", "lidl", "tesco", "costco", "grocery", "supermarket"],
            .dining: ["uber eats", "doordash", "starbucks", "coffee", "cafe", "restaurant", "pizza", "sweetgreen", "chipotle", "deliveroo", "bakery"],
            .transport: ["uber", "lyft", "mta", "metro", "shell", "chevron", "parking", "transit", "bolt"],
            .housing: ["rent", "apartments", "mortgage", "landlord"],
            .utilities: ["electric", "power", "water", "comcast", "verizon", "at&t", "internet", "mobile"],
            .subscriptions: ["netflix", "spotify", "icloud", "apple com bill", "youtube premium", "disney", "patreon"],
            .shopping: ["amazon", "target", "uniqlo", "ikea", "best buy", "zara"],
            .travel: ["airlines", "airways", "air", "hotel", "airbnb", "booking com", "expedia"],
            .health: ["pharmacy", "cvs", "walgreens", "dental", "clinic", "fitness", "gym"],
            .entertainment: ["cinema", "amc", "ticketmaster", "steam", "theatre", "museum"],
            .income: ["payroll", "salary", "refund", "interest"],
            .transfer: ["transfer", "payment thank you", "autopay"],
        ]
        return table.flatMap { category, keywords in
            keywords.map { CategoryRule(keyword: $0, category: category, isLearned: false, createdAt: .distantPast) }
        }
    }()
}
