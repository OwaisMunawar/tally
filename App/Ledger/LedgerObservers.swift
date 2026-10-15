import CoreSpotlight
import Foundation
import OSLog
import TallyCore
import UserNotifications
import WidgetKit

/// Keeps the home-screen widget in step with the ledger.
struct WidgetRefresher: LedgerChangeObserving {
    func ledgerDidChange(_ engine: LedgerQueryEngine) async {
        WidgetCenter.shared.reloadAllTimelines()
    }
}

/// Indexes recent transactions and payees so they show up in Spotlight.
///
/// Only the last 90 days are indexed: enough to find "that Uber last week"
/// without putting a whole financial history into the system index.
struct SpotlightIndexer: LedgerChangeObserving {
    func ledgerDidChange(_ engine: LedgerQueryEngine) async {
        let recent = engine.find(TransactionSearch(range: .lastDays(90, endingOn: engine.now, calendar: engine.calendar), limit: 1_000))
        let payees = engine.topPayees(in: .year(containing: engine.now, calendar: engine.calendar), limit: 200)
        let index = CSSearchableIndex.default()
        // Stale entries are cleared best-effort: a failed delete must not stop fresh items being indexed.
        try? await index.deleteAppEntities(ofType: TransactionEntity.self)
        do {
            try await index.indexAppEntities(recent.map(TransactionEntity.init))
            try await index.indexAppEntities(payees.map(PayeeEntity.init))
            Logger.ledger.info("Indexed \(recent.count) transactions and \(payees.count) payees for Spotlight")
        } catch {
            Logger.ledger.error("Spotlight indexing failed: \(String(describing: error), privacy: .public)")
        }
    }
}

/// Posts a local notification the first time a budget goes over in a month.
struct BudgetAlertNotifier: LedgerChangeObserving {
    let calendar: Calendar
    private let sentKey = "sentBudgetAlerts"

    func ledgerDidChange(_ engine: LedgerQueryEngine) async {
        let policy = BudgetAlertPolicy(calendar: calendar)
        let month = engine.currentMonth
        let defaults = SharedLedger.defaults
        let sent = policy.pruned(Set(defaults.stringArray(forKey: sentKey) ?? []), keeping: month)
        let exceeded = policy.newlyExceeded(engine.budgetStatuses(in: month), month: month, alreadySent: sent)
        guard !exceeded.isEmpty else { return }

        let center = UNUserNotificationCenter.current()
        // Provisional authorisation delivers quietly to Notification Center
        // without interrupting the user with a permission prompt.
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .provisional])
        var delivered = sent
        for status in exceeded {
            let content = UNMutableNotificationContent()
            content.title = "\(status.budget.category.displayName) is over budget"
            content.body = "You've spent \(status.spent.formatted()) of your \(status.budget.monthlyLimit.formatted()) budget this month."
            content.threadIdentifier = "budgets"
            content.userInfo = ["route": PendingRoute.budgets.rawValue]
            let key = policy.key(for: status, month: month)
            do {
                try await center.add(UNNotificationRequest(identifier: key, content: content, trigger: nil))
                delivered.insert(key)
            } catch {
                Logger.ledger.error("Budget alert failed: \(error.localizedDescription, privacy: .public)")
            }
        }
        defaults.set(Array(delivered), forKey: sentKey)
    }
}
