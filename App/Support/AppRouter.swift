import Observation
import SwiftUI

enum AppTab: String, Hashable, CaseIterable {
    case home, activity, insights, budgets, ask
}

enum AppSheet: String, Identifiable {
    case quickAdd = "add"
    case store
    case importCSV = "import"
    case settings

    var id: String { rawValue }
}

/// Navigation state shared by the tab bar, sheets, intents and launch arguments.
@MainActor
@Observable
final class AppRouter {
    var tab: AppTab = .home
    var sheet: AppSheet?
    var pendingQuestion: String?
    /// Opens the newest transaction from this payee in Activity; used by screenshot runs.
    var focusedPayee: String?

    func handle(_ route: PendingRoute) {
        switch route {
        case .quickAdd:
            sheet = .quickAdd
        case .budgets:
            sheet = nil
            tab = .budgets
        case .ask:
            sheet = nil
            tab = .ask
        }
    }

    func handlePendingRoute() {
        if let route = PendingRoute.consume() { handle(route) }
    }

    func open(_ url: URL) {
        guard url.scheme == "tally" else { return }
        switch url.host() {
        case "add": sheet = .quickAdd
        case "budgets": tab = .budgets
        case "ask": tab = .ask
        case "insights": tab = .insights
        default: tab = .home
        }
    }
}
