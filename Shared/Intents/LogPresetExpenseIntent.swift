import AppIntents
import Foundation
import TallyCore
import WidgetKit

/// Logs a repeat purchase straight from the widget, without opening the app.
/// Presets are the user's own most frequent small purchases.
struct LogPresetExpenseIntent: AppIntent {
    static let title: LocalizedStringResource = "Log Repeat Purchase"
    static let isDiscoverable = false

    @Parameter(title: "Payee")
    var payee: String

    @Parameter(title: "Amount in minor units")
    var minorUnits: Int

    @Parameter(title: "Currency")
    var currencyCode: String

    @Parameter(title: "Category")
    var categoryRaw: String

    @Parameter(title: "Account")
    var accountID: String

    init() {}

    init(preset: WidgetPreset) {
        payee = preset.payee
        minorUnits = Int(preset.amount.minorUnits)
        currencyCode = preset.amount.currency.rawValue
        categoryRaw = preset.category.rawValue
        accountID = preset.accountID.uuidString
    }

    func perform() async throws -> some IntentResult {
        guard let account = UUID(uuidString: accountID) else { return .result() }
        let transaction = LedgerTransaction(
            accountID: account,
            payee: payee,
            amount: Money(minorUnits: -Int64(abs(minorUnits)), currency: CurrencyCode(currencyCode)),
            category: TransactionCategory(rawValue: categoryRaw) ?? .other,
            categorization: .manual,
            date: .now,
            tags: ["widget"]
        )
        try await SharedLedger.makeRepository().upsert(transaction)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

/// A one-tap purchase shown on the medium widget.
struct WidgetPreset: Hashable, Sendable {
    let payee: String
    let amount: Money
    let category: TransactionCategory
    let accountID: UUID

    /// The two payees bought most often in the last 30 days at under 20 units,
    /// priced at their most recent amount.
    static func presets(from engine: LedgerQueryEngine, limit: Int = 2) -> [WidgetPreset] {
        let recent = engine.find(TransactionSearch(range: .lastDays(30, endingOn: engine.now, calendar: engine.calendar), limit: 500))
            .filter { $0.isOutflow && $0.amount.magnitude.minorUnits < 20 * 100 && $0.category.isSpending }
        let grouped = Dictionary(grouping: recent) { PayeeNormalizer.normalize($0.payee) }
        return grouped.values
            .sorted { $0.count != $1.count ? $0.count > $1.count : ($0.first?.payee ?? "") < ($1.first?.payee ?? "") }
            .prefix(limit)
            .compactMap { group in
                guard let latest = group.first else { return nil }
                return WidgetPreset(payee: latest.payee, amount: latest.amount.magnitude, category: latest.category, accountID: latest.accountID)
            }
    }
}
