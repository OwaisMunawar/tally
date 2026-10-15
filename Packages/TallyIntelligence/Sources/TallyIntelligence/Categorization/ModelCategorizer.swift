import Foundation
import FoundationModels
import TallyCore

/// Structured output for one categorisation. `anyOf` makes it impossible for
/// the model to return a category Tally doesn't have.
@Generable(description: "The spending category for one bank transaction")
struct CategoryGuess {
    @Guide(description: "The best matching category", .anyOf(TransactionCategory.allCases.map(\.rawValue)))
    var category: String

    @Guide(description: "How confident you are, from 0 (guessing) to 100 (certain)", .range(0...100))
    var confidence: Int
}

/// Categorises with Apple's on-device model using guided generation.
public struct ModelCategorizer: TransactionCategorizing {
    private let model: SystemLanguageModel

    public init(model: SystemLanguageModel = .default) {
        self.model = model
    }

    public func suggest(payee: String, amount: Money, notes: String) async -> CategorySuggestion? {
        guard AssistantAvailability.current.isAvailable else { return nil }
        // A fresh session per transaction keeps one guess from biasing the next.
        let session = LanguageModelSession(model: model, instructions: Self.instructions)
        let direction = amount.isNegative ? "money out" : "money in"
        let prompt = "Payee: \(payee)\nAmount: \(amount.magnitude.formatted(locale: Locale(identifier: "en_US"))) (\(direction))"
            + (notes.isEmpty ? "" : "\nNotes: \(notes)")
        do {
            let response = try await session.respond(to: prompt, generating: CategoryGuess.self, options: GenerationOptions(sampling: .greedy))
            guard let category = TransactionCategory(rawValue: response.content.category) else { return nil }
            let confidence = min(100, max(0, response.content.confidence))
            return CategorySuggestion(category: category, source: .model(confidence: confidence))
        } catch {
            return nil
        }
    }

    static let instructions: String = {
        let definitions = TransactionCategory.allCases.map { "- \($0.rawValue): \($0.definition)" }.joined(separator: "\n")
        return """
        You categorise bank and card transactions. Bank descriptors are often abbreviated, \
        prefixed by a payment processor (SQ *, TST*, PAYPAL *) or followed by store numbers and cities. \
        Choose exactly one category:
        \(definitions)
        Report low confidence when the payee could reasonably belong to more than one category.
        """
    }()
}
