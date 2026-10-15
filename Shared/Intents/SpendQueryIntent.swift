import AppIntents
import Foundation
import TallyCore

/// "How much did I spend on dining in Tally?" Answers from the same query
/// engine the app uses, so Siri and the app always agree.
struct SpendQueryIntent: AppIntent {
    static let title: LocalizedStringResource = "How Much Did I Spend"
    static let description = IntentDescription("Get your spending in a category for a period.")

    @Parameter(title: "Category")
    var category: CategoryAppEnum

    @Parameter(title: "Period", default: .thisMonth)
    var period: SpendPeriodAppEnum

    static var parameterSummary: some ParameterSummary {
        Summary("Spending on \(\.$category) for \(\.$period)")
    }

    init() {}

    init(category: CategoryAppEnum, period: SpendPeriodAppEnum = .thisMonth) {
        self.category = category
        self.period = period
    }

    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<String> {
        let engine = try await SharedLedger.engine()
        guard let resolved = engine.periodParser.parse(period.rawValue) else { throw IntentFailure.unknownPeriod }
        let summary = engine.spending(in: resolved.range, categories: [category.category])
        let answer = summary.transactionCount == 0
            ? "You haven't spent anything on \(category.category.displayName.lowercased()) in \(resolved.label)."
            : "You've spent \(summary.total.formatted()) on \(category.category.displayName.lowercased()) in \(resolved.label), "
                + "across \(summary.transactionCount) transactions."
        return .result(value: summary.total.formatted(), dialog: "\(answer)")
    }
}
