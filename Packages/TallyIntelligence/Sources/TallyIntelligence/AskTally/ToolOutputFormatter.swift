import Foundation
import TallyCore

/// Renders query results as short, regular text for the model.
///
/// The model copies figures from here into its answer, so every amount uses
/// one fixed locale and full minor-unit precision, and every comparison
/// spells out direction in words. That way the model never has to do sums
/// or decide what a negative difference means.
struct ToolOutputFormatter: Sendable {
    let calendar: Calendar
    let locale = Locale(identifier: "en_US")

    func money(_ value: Money) -> String {
        value.formatted(locale: locale)
    }

    func count(_ value: Int) -> String {
        value == 1 ? "1 transaction" : "\(value) transactions"
    }

    func percent(_ value: Decimal) -> String {
        "\(NSDecimalNumber(decimal: value.magnitude).stringValue)%"
    }

    func day(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted, locale: locale, calendar: calendar, timeZone: calendar.timeZone))
    }

    func spendByCategory(_ totals: [CategoryTotal], period: ResolvedPeriod) -> String {
        guard !totals.isEmpty else { return "No spending recorded in \(period.label)." }
        let lines = totals.map { "- \($0.category.displayName): \(money($0.total)) (\(count($0.transactionCount)))" }
        let total = totals.reduce(Int64(0)) { $0 + $1.total.minorUnits }
        let currency = totals[0].total.currency
        let all = totals.reduce(0) { $0 + $1.transactionCount }
        return (["Spending by category in \(period.label):"] + lines + ["Total: \(money(Money(minorUnits: total, currency: currency))) (\(count(all)))"])
            .joined(separator: "\n")
    }

    func spending(_ summary: SpendSummary, label: String, period: ResolvedPeriod) -> String {
        "Spending on \(label) in \(period.label): \(money(summary.total)) across \(count(summary.transactionCount))."
    }

    func comparison(_ result: RangeComparison, label: String, first: ResolvedPeriod, second: ResolvedPeriod) -> String {
        var lines = [
            "Spending on \(label), \(first.label) compared with \(second.label):",
            "- \(first.label): \(money(result.first.total)) (\(count(result.first.transactionCount)))",
            "- \(second.label): \(money(result.second.total)) (\(count(result.second.transactionCount)))",
        ]
        if result.difference.isZero {
            lines.append("- Difference: none, the totals are equal")
        } else {
            let direction = result.difference.isPositive ? "more" : "less"
            var line = "- Difference: \(money(result.difference.magnitude)) \(direction) in \(first.label)"
            if let change = result.percentChange {
                line += " (\(percent(change)) \(result.difference.isPositive ? "higher" : "lower"))"
            }
            lines.append(line)
        }
        return lines.joined(separator: "\n")
    }

    func payees(_ payees: [PayeeTotal], label: String, period: ResolvedPeriod) -> String {
        guard !payees.isEmpty else { return "No spending on \(label) in \(period.label)." }
        let lines = payees.enumerated().map { index, payee in
            "\(index + 1). \(payee.payee): \(money(payee.total)) (\(count(payee.transactionCount)))"
        }
        return (["Top payees for \(label) in \(period.label):"] + lines).joined(separator: "\n")
    }

    func transactions(_ transactions: [LedgerTransaction], engine: LedgerQueryEngine, description: String) -> String {
        guard !transactions.isEmpty else { return "No transactions matched \(description)." }
        let lines = transactions.map { transaction in
            var line = "- \(day(transaction.date)) \(transaction.payee): \(money(transaction.amount))"
            if transaction.amount.currency != engine.baseCurrency {
                line += " (\(money(engine.baseAmount(of: transaction))))"
            }
            return line + " [\(transaction.category.displayName)]"
        }
        return (["Transactions matching \(description) (newest first):"] + lines).joined(separator: "\n")
    }

    func budgets(_ statuses: [BudgetStatus], period: ResolvedPeriod) -> String {
        guard !statuses.isEmpty else { return "No budgets are set." }
        let lines = statuses.map { status in
            let state = switch status.state {
            case .onTrack: "on track"
            case .nearLimit: "close to the limit"
            case .over: "over budget"
            }
            let left = status.remaining.isNegative
                ? "\(money(status.remaining.magnitude)) over"
                : "\(money(status.remaining)) left"
            return "- \(status.budget.category.displayName): spent \(money(status.spent)) of \(money(status.budget.monthlyLimit)), \(left), \(state)"
        }
        return (["Budgets for \(period.label):"] + lines).joined(separator: "\n")
    }
}
