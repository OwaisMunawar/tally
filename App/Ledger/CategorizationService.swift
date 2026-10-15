import Foundation
import Observation
import TallyCore
import TallyIntelligence

/// Runs the hybrid categoriser for the UI and reports progress.
@MainActor
@Observable
final class CategorizationService {
    private(set) var isRunning = false
    private(set) var lastSummary: String?

    var availability: AssistantAvailability { AssistantAvailability.current }

    func makeCategorizer(rules: [CategoryRule]) -> HybridCategorizer {
        HybridCategorizer(
            rules: RuleBasedCategorizer(learnedRules: rules),
            model: AssistantAvailability.current.isAvailable ? ModelCategorizer() : nil
        )
    }

    func suggest(payee: String, amount: Money, rules: [CategoryRule]) async -> CategorySuggestion? {
        guard !payee.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        return await makeCategorizer(rules: rules).suggest(payee: payee, amount: amount, notes: "")
    }

    func categorizePending(in ledger: LedgerStore) async {
        guard !isRunning else { return }
        isRunning = true
        defer { isRunning = false }
        let pending = ledger.pendingReview
        let updated = await makeCategorizer(rules: ledger.data.rules).categorizeUncategorized(pending)
        await ledger.save(updated)
        let byModel = updated.filter { if case .model = $0.categorization { true } else { false } }.count
        lastSummary = "Categorised \(updated.count) of \(pending.count)" + (byModel > 0 ? ", \(byModel) on device with Apple Intelligence." : " with rules.")
    }
}

/// Produces the monthly insight card, regenerating only when the facts change.
@MainActor
@Observable
final class InsightService {
    private(set) var insight: MonthlyInsight?
    private(set) var isGenerating = false
    @ObservationIgnored private var lastFacts: InsightFacts?

    func refresh(using engine: LedgerQueryEngine) async {
        let facts = InsightFacts(engine: engine)
        guard facts != lastFacts, !isGenerating else { return }
        lastFacts = facts
        isGenerating = true
        defer { isGenerating = false }
        insight = await ModelInsightWriter().insight(for: facts)
    }
}
