import Foundation

/// Decides which over-budget alerts to send, at most once per category per month.
///
/// The app re-evaluates budgets after every change, so without this ledger of
/// sent alerts a user would be notified again for each coffee bought after
/// going over.
public struct BudgetAlertPolicy: Sendable {
    public let calendar: Calendar

    public init(calendar: Calendar) {
        self.calendar = calendar
    }

    /// A stable key such as `2026-10:dining`.
    public func key(for status: BudgetStatus, month: DateRange) -> String {
        let components = calendar.dateComponents([.year, .month], from: month.start)
        return String(format: "%04d-%02d:", components.year ?? 0, components.month ?? 0) + status.budget.category.rawValue
    }

    /// Statuses that just went over and have not been alerted yet this month.
    public func newlyExceeded(_ statuses: [BudgetStatus], month: DateRange, alreadySent: Set<String>) -> [BudgetStatus] {
        statuses.filter { $0.state == .over && !alreadySent.contains(key(for: $0, month: month)) }
    }

    /// Drops keys from earlier months so the stored set never grows without bound.
    public func pruned(_ sent: Set<String>, keeping month: DateRange) -> Set<String> {
        let components = calendar.dateComponents([.year, .month], from: month.start)
        let prefix = String(format: "%04d-%02d:", components.year ?? 0, components.month ?? 0)
        return sent.filter { $0.hasPrefix(prefix) }
    }
}
