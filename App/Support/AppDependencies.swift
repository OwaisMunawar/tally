import Foundation
import TallyCore

/// The object graph, built once at launch. Views receive these through the
/// environment; nothing reaches for a global.
@MainActor
struct AppDependencies {
    let ledger: LedgerStore
    let plus: PlusStore
    let lock: AppLock
    let router: AppRouter
    let categorization: CategorizationService
    let insights: InsightService

    static func live(options: LaunchOptions) -> AppDependencies {
        let ledger = LedgerStore(
            repository: SharedLedger.makeRepository(),
            calendar: SharedLedger.calendar,
            observers: [WidgetRefresher(), SpotlightIndexer(), BudgetAlertNotifier(calendar: SharedLedger.calendar)]
        )
        return AppDependencies(
            ledger: ledger,
            plus: PlusStore(forcePlus: options.unlockPlus),
            lock: AppLock(),
            router: AppRouter(),
            categorization: CategorizationService(),
            insights: InsightService()
        )
    }

    /// In-memory graph seeded with demo data, for previews and tests.
    static func preview(now: Date = .now) -> AppDependencies {
        let calendar = Calendar.autoupdatingCurrent
        let ledger = LedgerStore(
            repository: InMemoryLedgerRepository(DemoLedger(now: now, calendar: calendar).make()),
            calendar: calendar,
            observers: []
        )
        return AppDependencies(
            ledger: ledger,
            plus: PlusStore(forcePlus: true),
            lock: AppLock(defaults: UserDefaults(suiteName: "preview") ?? .standard),
            router: AppRouter(),
            categorization: CategorizationService(),
            insights: InsightService()
        )
    }
}
