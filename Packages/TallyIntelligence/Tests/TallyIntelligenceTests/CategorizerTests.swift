import Foundation
import Testing
import TallyCore
@testable import TallyIntelligence

/// Stands in for the on-device model with a scripted answer.
struct ScriptedCategorizer: TransactionCategorizing {
    let answer: CategorySuggestion?

    func suggest(payee: String, amount: Money, notes: String) async -> CategorySuggestion? {
        answer
    }
}

@Suite("Hybrid categoriser")
struct CategorizerTests {
    let coffee = Ledger.usd(-6_25)

    @Test("A learned correction beats a confident model")
    func learnedFirst() async {
        let rules = RuleBasedCategorizer(learnedRules: [CategoryRule(keyword: "ritual", category: .groceries, isLearned: true)])
        let model = ScriptedCategorizer(answer: CategorySuggestion(category: .dining, source: .model(confidence: 95)))
        let result = await HybridCategorizer(rules: rules, model: model).suggest(payee: "SQ *RITUAL ROASTERS", amount: coffee)
        #expect(result?.category == .groceries)
    }

    @Test("The model handles descriptors no keyword knows")
    func modelForUnknown() async {
        let model = ScriptedCategorizer(answer: CategorySuggestion(category: .dining, source: .model(confidence: 81)))
        let result = await HybridCategorizer(rules: RuleBasedCategorizer(learnedRules: []), model: model)
            .suggest(payee: "SQ *RITUAL ROASTERS", amount: coffee)
        #expect(result?.source == .model(confidence: 81))
    }

    @Test("A known merchant keyword beats even a confident model guess")
    func keywordBeatsModel() async {
        let model = ScriptedCategorizer(answer: CategorySuggestion(category: .groceries, source: .model(confidence: 100)))
        let result = await HybridCategorizer(rules: RuleBasedCategorizer(learnedRules: []), model: model)
            .suggest(payee: "WALGREENS #4471", amount: Ledger.usd(-18_42))
        #expect(result?.category == .health)
    }

    @Test("An unsure model guess is discarded rather than trusted")
    func lowConfidenceDiscarded() async {
        let model = ScriptedCategorizer(answer: CategorySuggestion(category: .shopping, source: .model(confidence: 30)))
        let result = await HybridCategorizer(rules: RuleBasedCategorizer(learnedRules: []), model: model)
            .suggest(payee: "Mystery Vendor", amount: Ledger.usd(-12_00))
        #expect(result == nil)
    }

    @Test("Without Apple Intelligence the keyword rules still categorise")
    func fallbackWithoutModel() async {
        let categorizer = HybridCategorizer(rules: RuleBasedCategorizer(learnedRules: []), model: nil)
        #expect(await categorizer.suggest(payee: "WALGREENS #4471", amount: Ledger.usd(-18_42))?.category == .health)
        #expect(await categorizer.suggest(payee: "Mystery Vendor", amount: Ledger.usd(-1_00)) == nil)
    }

    @Test("Batch categorisation only touches uncategorised transactions")
    func batch() async {
        let reviewed = LedgerTransaction(accountID: UUID(), payee: "Lyft", amount: Ledger.usd(-9_00), category: .other,
                                         categorization: .manual, date: .now)
        let pending = LedgerTransaction(accountID: UUID(), payee: "LYFT *RIDE", amount: Ledger.usd(-21_60), category: .other,
                                        categorization: .uncategorized, date: .now)
        let updated = await HybridCategorizer(rules: RuleBasedCategorizer(learnedRules: []), model: nil)
            .categorizeUncategorized([reviewed, pending])
        #expect(updated.map(\.id) == [pending.id])
        #expect(updated.first?.category == .transport)
    }
}

@Suite("Transcript and insight plumbing")
struct PlumbingTests {
    @Test("Tool arguments JSON becomes sorted key-value pairs")
    func arguments() {
        let parsed = ToolInvocation.arguments(fromJSON: #"{"period":"2026-09","category":"food"}"#)
        #expect(parsed == [.init(name: "category", value: "food"), .init(name: "period", value: "2026-09")])
    }

    @Test("The template insight only quotes engine figures")
    func templateInsight() async throws {
        let engine = try Ledger.engine()
        let september = DateRange.month(containing: Ledger.date(2026, 9, 1), calendar: Ledger.calendar)
        let facts = InsightFacts(engine: engine, month: september)
        let insight = await TemplateInsightWriter().insight(for: facts)
        #expect(insight.source == .template)
        #expect(insight.body == "You've spent $139.50 so far, most of it on groceries ($84.20).")
        #expect(GroundingValidator().validate(answer: insight.body, evidence: [facts.evidence]).isGrounded)
    }
}
