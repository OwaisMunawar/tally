import Foundation
import OSLog
import SwiftData
import TallyCore
import TallyData

/// Composition root for persistence, compiled into the app and the widget
/// extension so both open the same store inside the App Group container.
enum SharedLedger {
    static let appGroup = "group.com.owaismunawar.tally"

    static let container: ModelContainer = {
        do {
            return try TallyStore.makeContainer(location: .appGroup(appGroup), cloudKit: BuildFlags.cloudKitSync)
        } catch {
            // A store that can't open shouldn't brick the app or the widget.
            Logger.ledger.error("Falling back to an in-memory store: \(error.localizedDescription, privacy: .public)")
            do {
                return try TallyStore.makeContainer(location: .inMemory)
            } catch {
                fatalError("Unable to create even an in-memory ModelContainer: \(error)")
            }
        }
    }()

    static func makeRepository() -> any LedgerRepository {
        SwiftDataLedgerRepository(modelContainer: container)
    }

    static var calendar: Calendar { .autoupdatingCurrent }

    /// A query engine over the latest data, for intents and widget timelines.
    static func engine(now: Date = .now) async throws -> LedgerQueryEngine {
        let data = try await makeRepository().load()
        return try LedgerQueryEngine(data: data, calendar: calendar, now: now)
    }

    static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroup) ?? .standard
    }
}

enum BuildFlags {
    #if TALLY_CLOUDKIT
    static let cloudKitSync = true
    #else
    static let cloudKitSync = false
    #endif
}

enum WidgetKinds {
    static let budget = "com.owaismunawar.tally.budget"
    static let quickAddControl = "com.owaismunawar.tally.quick-add"
}

extension Logger {
    private static let subsystem = "com.owaismunawar.tally"
    static let ledger = Logger(subsystem: subsystem, category: "ledger")
    static let intents = Logger(subsystem: subsystem, category: "intents")
    static let store = Logger(subsystem: subsystem, category: "store")
}
