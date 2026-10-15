import Foundation
import FoundationModels
import TallyCore

// Each tool is a thin adapter: parse loose arguments, call `LedgerQueryEngine`,
// format the result. No tool does arithmetic of its own, so the numbers the
// model sees are exactly the numbers the charts and budgets show.

private let periodGuide = "A period: this_month, last_month, last_30_days, last_3_months, this_year, last_year, "
    + "a month as YYYY-MM such as 2026-09, or a year such as 2026"

private let categoryGuide = "A category or group, or 'all' for all spending"

/// Shared context every tool needs.
struct ToolContext: Sendable {
    let engine: LedgerQueryEngine
    var formatter: ToolOutputFormatter { ToolOutputFormatter(calendar: engine.calendar) }

    func period(_ text: String) -> ResolvedPeriod? {
        engine.periodParser.parse(text)
    }

    func unknownPeriod(_ text: String) -> String {
        "Unrecognised period '\(text)'. Use this_month, last_month, last_30_days, this_year, YYYY-MM or YYYY."
    }

    func categories(_ token: String) -> (set: Set<TransactionCategory>?, label: String) {
        let set = CategoryVocabulary.categories(for: token)
        return (set, CategoryVocabulary.label(for: set))
    }
}

struct SpendByCategoryTool: Tool {
    let name = "spendByCategory"
    let description = "Total spending in ONE period, by category or for one category or group such as food. "
        + "To compare two periods, use compareRanges instead."
    let context: ToolContext

    @Generable
    struct Arguments {
        @Guide(description: periodGuide)
        var period: String
        @Guide(description: categoryGuide, .anyOf(CategoryVocabulary.tokens))
        var category: String
    }

    func call(arguments: Arguments) async throws -> String {
        guard let period = context.period(arguments.period) else { return context.unknownPeriod(arguments.period) }
        let filter = context.categories(arguments.category)
        if let set = filter.set {
            return context.formatter.spending(context.engine.spending(in: period.range, categories: set), label: filter.label, period: period)
        }
        return context.formatter.spendByCategory(context.engine.spendByCategory(in: period.range), period: period)
    }
}

struct CompareRangesTool: Tool {
    let name = "compareRanges"
    let description = "Use for any question comparing two periods (X vs Y, more or less than). "
        + "Returns both totals, the difference and the percent change."
    let context: ToolContext

    @Generable
    struct Arguments {
        @Guide(description: "The period being asked about. " + periodGuide)
        var firstPeriod: String
        @Guide(description: "The period to compare against. " + periodGuide)
        var secondPeriod: String
        @Guide(description: categoryGuide, .anyOf(CategoryVocabulary.tokens))
        var category: String
    }

    func call(arguments: Arguments) async throws -> String {
        guard let first = context.period(arguments.firstPeriod) else { return context.unknownPeriod(arguments.firstPeriod) }
        guard let second = context.period(arguments.secondPeriod) else { return context.unknownPeriod(arguments.secondPeriod) }
        let filter = context.categories(arguments.category)
        let result = context.engine.compare(first.range, with: second.range, categories: filter.set)
        return context.formatter.comparison(result, label: filter.label, first: first, second: second)
    }
}

struct TopPayeesTool: Tool {
    let name = "topPayees"
    let description = "The merchants the user spent the most with in a period, optionally within a category."
    let context: ToolContext

    @Generable
    struct Arguments {
        @Guide(description: periodGuide)
        var period: String
        @Guide(description: categoryGuide, .anyOf(CategoryVocabulary.tokens))
        var category: String
        @Guide(description: "How many payees to return", .range(1...10))
        var limit: Int
    }

    func call(arguments: Arguments) async throws -> String {
        guard let period = context.period(arguments.period) else { return context.unknownPeriod(arguments.period) }
        let filter = context.categories(arguments.category)
        let payees = context.engine.topPayees(in: period.range, categories: filter.set, limit: arguments.limit)
        return context.formatter.payees(payees, label: filter.label, period: period)
    }
}

struct FindTransactionsTool: Tool {
    let name = "findTransactions"
    let description = "Searches individual transactions by payee or note text, category and period."
    let context: ToolContext

    @Generable
    struct Arguments {
        @Guide(description: "Words to look for in the payee or notes, or an empty string to match any")
        var query: String
        @Guide(description: periodGuide + ", or 'all' for any time")
        var period: String
        @Guide(description: categoryGuide, .anyOf(CategoryVocabulary.tokens))
        var category: String
        @Guide(description: "Maximum number of transactions", .range(1...15))
        var limit: Int
    }

    func call(arguments: Arguments) async throws -> String {
        let period = arguments.period.lowercased() == "all" ? nil : context.period(arguments.period)
        if period == nil && arguments.period.lowercased() != "all" { return context.unknownPeriod(arguments.period) }
        let filter = context.categories(arguments.category)
        let search = TransactionSearch(
            text: arguments.query,
            categories: filter.set,
            range: period?.range,
            limit: arguments.limit
        )
        var description = arguments.query.isEmpty ? filter.label : "'\(arguments.query)'"
        if let period { description += " in \(period.label)" }
        return context.formatter.transactions(context.engine.find(search), engine: context.engine, description: description)
    }
}

struct BudgetStatusTool: Tool {
    let name = "budgetStatus"
    let description = "How each monthly budget is doing: spent, limit, amount left and whether it is over."
    let context: ToolContext

    @Generable
    struct Arguments {
        @Guide(description: "The month to check, usually this_month, or YYYY-MM")
        var month: String
    }

    func call(arguments: Arguments) async throws -> String {
        guard let period = context.period(arguments.month) else { return context.unknownPeriod(arguments.month) }
        let month = DateRange.month(containing: period.range.start, calendar: context.engine.calendar)
        return context.formatter.budgets(context.engine.budgetStatuses(in: month), period: period)
    }
}

enum LedgerTools {
    static func all(engine: LedgerQueryEngine) -> [any Tool] {
        let context = ToolContext(engine: engine)
        return [
            SpendByCategoryTool(context: context),
            CompareRangesTool(context: context),
            TopPayeesTool(context: context),
            FindTransactionsTool(context: context),
            BudgetStatusTool(context: context),
        ]
    }
}
