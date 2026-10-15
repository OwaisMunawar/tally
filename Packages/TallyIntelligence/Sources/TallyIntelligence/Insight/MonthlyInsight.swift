import Foundation
import FoundationModels
import TallyCore

/// The figures a monthly insight may mention, computed by the query engine.
public struct InsightFacts: Hashable, Sendable {
    public let monthLabel: String
    public let previousMonthLabel: String
    public let spent: Money
    public let previousSpent: Money
    public let percentChange: Decimal?
    public let topCategory: CategoryTotal?
    public let overBudget: [BudgetStatus]

    public init(engine: LedgerQueryEngine, month: DateRange? = nil) {
        let current = month ?? engine.currentMonth
        let previous = current.previousMonth(calendar: engine.calendar)
        let comparison = engine.compare(current, with: previous)
        let locale = Locale(identifier: "en_US")
        monthLabel = current.label(calendar: engine.calendar, locale: locale)
        previousMonthLabel = previous.label(calendar: engine.calendar, locale: locale)
        spent = comparison.first.total
        previousSpent = comparison.second.total
        percentChange = comparison.percentChange
        topCategory = engine.spendByCategory(in: current).first
        overBudget = engine.budgetStatuses(in: current).filter { $0.state == .over }
    }

    /// The facts as plain sentences, used both as the model prompt and as
    /// evidence for grounding the model's summary.
    public var evidence: String {
        let formatter = ToolOutputFormatter(calendar: Calendar(identifier: .gregorian))
        var lines = ["Spent in \(monthLabel) so far: \(formatter.money(spent)).", "Spent in \(previousMonthLabel): \(formatter.money(previousSpent))."]
        if let percentChange {
            let direction = percentChange >= 0 ? "higher" : "lower"
            lines.append("That is \(formatter.percent(percentChange)) \(direction) than \(previousMonthLabel) so far.")
        }
        if let topCategory {
            lines.append("Largest category: \(topCategory.category.displayName) at \(formatter.money(topCategory.total)).")
        }
        for status in overBudget {
            lines.append("\(status.budget.category.displayName) is over budget by \(formatter.money(status.remaining.magnitude)).")
        }
        return lines.joined(separator: "\n")
    }
}

public struct MonthlyInsight: Hashable, Sendable {
    public enum Source: Hashable, Sendable {
        case onDeviceModel, template
    }

    public let headline: String
    public let body: String
    public let source: Source
}

public protocol MonthlyInsightWriting: Sendable {
    func insight(for facts: InsightFacts) async -> MonthlyInsight
}

/// Deterministic fallback. Always available, always grounded.
public struct TemplateInsightWriter: MonthlyInsightWriting {
    public init() {}

    public func insight(for facts: InsightFacts) async -> MonthlyInsight {
        let formatter = ToolOutputFormatter(calendar: Calendar(identifier: .gregorian))
        let headline: String
        if let over = facts.overBudget.first {
            headline = "\(over.budget.category.displayName) is over budget"
        } else if let change = facts.percentChange, change < 0 {
            headline = "Spending is down on \(facts.previousMonthLabel)"
        } else {
            headline = "\(facts.monthLabel) at a glance"
        }
        var body = "You've spent \(formatter.money(facts.spent)) so far"
        if let top = facts.topCategory {
            body += ", most of it on \(top.category.displayName.lowercased()) (\(formatter.money(top.total)))"
        }
        body += "."
        return MonthlyInsight(headline: headline, body: body, source: .template)
    }
}

@Generable(description: "A short, friendly summary of the user's month")
struct GeneratedInsight {
    @Guide(description: "A headline of at most six words")
    var headline: String
    @Guide(description: "One or two sentences quoting figures exactly as given")
    var body: String
}

/// Writes the insight with the on-device model, and falls back to the template
/// whenever the model is unavailable or quotes a figure it wasn't given.
public struct ModelInsightWriter: MonthlyInsightWriting {
    private let fallback = TemplateInsightWriter()

    public init() {}

    public func insight(for facts: InsightFacts) async -> MonthlyInsight {
        guard AssistantAvailability.current.isAvailable else { return await fallback.insight(for: facts) }
        let session = LanguageModelSession(instructions: """
        You write a two-sentence monthly money summary for a personal finance app. \
        Be warm and specific. Use only the figures provided, copied exactly. Never calculate new figures.
        """)
        do {
            let response = try await session.respond(to: facts.evidence, generating: GeneratedInsight.self)
            let text = response.content.headline + " " + response.content.body
            guard GroundingValidator().validate(answer: text, evidence: [facts.evidence]).isGrounded else {
                return await fallback.insight(for: facts)
            }
            return MonthlyInsight(headline: response.content.headline, body: response.content.body, source: .onDeviceModel)
        } catch {
            return await fallback.insight(for: facts)
        }
    }
}
