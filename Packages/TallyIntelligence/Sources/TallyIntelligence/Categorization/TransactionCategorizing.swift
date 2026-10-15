import Foundation
import TallyCore

/// Anything that can propose a category for a transaction.
public protocol TransactionCategorizing: Sendable {
    func suggest(payee: String, amount: Money, notes: String) async -> CategorySuggestion?
}

/// The categoriser the app uses: the user's learned rules, then shipped
/// keyword rules, then the on-device model, then a sign-based fallback.
///
/// Learned rules go first because a correction the user made by hand is the
/// strongest signal there is. Keyword rules are precise for the merchants they
/// name, so they beat a guess; in testing the model happily filed a pharmacy
/// under groceries at full confidence. The model earns its place on the long
/// tail of descriptors no keyword list anticipates, and a guess below
/// `minimumModelConfidence` is discarded in favour of "needs review".
public struct HybridCategorizer: TransactionCategorizing {
    public let rules: RuleBasedCategorizer
    public let model: (any TransactionCategorizing)?
    public let minimumModelConfidence: Int

    public init(rules: RuleBasedCategorizer, model: (any TransactionCategorizing)?, minimumModelConfidence: Int = 55) {
        self.rules = rules
        self.model = model
        self.minimumModelConfidence = minimumModelConfidence
    }

    public func suggest(payee: String, amount: Money, notes: String = "") async -> CategorySuggestion? {
        if let keyword = rules.keywordMatch(payee: payee) { return keyword }
        if let model, let guess = await model.suggest(payee: payee, amount: amount, notes: notes),
           guess.confidence >= minimumModelConfidence {
            return guess
        }
        return rules.suggest(payee: payee, amount: amount)
    }

    /// Categorises every transaction still marked uncategorised, in order.
    /// Sequential on purpose: the on-device model serves one request at a time.
    public func categorizeUncategorized(_ transactions: [LedgerTransaction]) async -> [LedgerTransaction] {
        var updated: [LedgerTransaction] = []
        for var transaction in transactions where transaction.categorization == .uncategorized {
            guard let suggestion = await suggest(payee: transaction.payee, amount: transaction.amount, notes: transaction.notes) else {
                continue
            }
            transaction.category = suggestion.category
            transaction.categorization = suggestion.source
            updated.append(transaction)
        }
        return updated
    }
}
