import Foundation

/// Where an intent, widget or control wants the app to go.
///
/// Intents may run in the widget extension's process, so a route is written
/// to the shared App Group defaults and picked up when the app becomes active.
/// When the intent runs inside the app it also posts a notification so the
/// router reacts immediately.
enum PendingRoute: String, Sendable {
    case quickAdd
    case budgets
    case ask

    private static let key = "pendingRoute"

    static func request(_ route: PendingRoute) {
        SharedLedger.defaults.set(route.rawValue, forKey: key)
        NotificationCenter.default.post(name: .tallyRouteRequested, object: nil)
    }

    /// Returns and clears the pending route.
    static func consume() -> PendingRoute? {
        let defaults = SharedLedger.defaults
        guard let raw = defaults.string(forKey: key) else { return nil }
        defaults.removeObject(forKey: key)
        return PendingRoute(rawValue: raw)
    }
}

extension Notification.Name {
    static let tallyRouteRequested = Notification.Name("com.owaismunawar.tally.routeRequested")
}
