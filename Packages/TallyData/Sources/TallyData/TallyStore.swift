import Foundation
import SwiftData

/// Builds the SwiftData container shared by the app and its extensions.
public enum TallyStore {
    public static let schema = Schema([
        AccountRecord.self,
        TransactionRecord.self,
        BudgetRecord.self,
        RecurringRecord.self,
        CategoryRuleRecord.self,
        ExchangeRateRecord.self,
    ])

    public enum Location: Sendable {
        case inMemory
        /// Inside an App Group container so the widget and controls can read it.
        case appGroup(String)
        case url(URL)
    }

    /// - Parameter cloudKit: mirror to the user's private iCloud database. Off by
    ///   default because it needs a team ID and an iCloud container entitlement.
    public static func makeContainer(location: Location, cloudKit: Bool = false) throws -> ModelContainer {
        let database: ModelConfiguration.CloudKitDatabase = cloudKit ? .automatic : .none
        let configuration: ModelConfiguration
        switch location {
        case .inMemory:
            configuration = ModelConfiguration("Tally", schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        case .appGroup(let identifier):
            configuration = ModelConfiguration("Tally", schema: schema, groupContainer: .identifier(identifier), cloudKitDatabase: database)
        case .url(let url):
            configuration = ModelConfiguration("Tally", schema: schema, url: url, cloudKitDatabase: database)
        }
        return try ModelContainer(for: schema, configurations: configuration)
    }
}
