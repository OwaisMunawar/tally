import AppIntents
import Foundation
import OSLog
import TallyCore
import WidgetKit

/// "Add an expense in Tally": logs a transaction without opening the app.
struct AddExpenseIntent: AppIntent {
    static let title: LocalizedStringResource = "Add Expense"
    static let description = IntentDescription("Log a purchase in Tally. If you don't pick a category, Tally's rules choose one.")

    @Parameter(title: "Amount")
    var amount: IntentCurrencyAmount

    @Parameter(title: "Payee", requestValueDialog: "Where did you spend it?")
    var payee: String

    @Parameter(title: "Category")
    var category: CategoryAppEnum?

    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$amount) at \(\.$payee)") {
            \.$category
        }
    }

    init() {}

    init(amount: IntentCurrencyAmount, payee: String, category: CategoryAppEnum? = nil) {
        self.amount = amount
        self.payee = payee
        self.category = category
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let repository = SharedLedger.makeRepository()
        let data = try await repository.load()
        let currency = CurrencyCode(amount.currencyCode)
        guard let account = data.accounts.first(where: { $0.currency == currency && $0.kind == .card })
            ?? data.accounts.first(where: { $0.currency == currency })
            ?? data.accounts.first else {
            throw IntentFailure.noAccounts
        }

        // Store in the account's currency so balances never mix currencies.
        let entered = try Money(amount.amount.magnitude, currency: currency).negated
        let value = try data.rates.convert(entered, to: account.currency)

        let resolved: CategorySuggestion = if let category {
            CategorySuggestion(category: category.category, source: .manual)
        } else {
            RuleBasedCategorizer(learnedRules: data.rules).suggest(payee: payee, amount: value)
                ?? CategorySuggestion(category: .other, source: .uncategorized)
        }

        let transaction = LedgerTransaction(
            accountID: account.id,
            payee: payee,
            amount: value,
            category: resolved.category,
            categorization: resolved.source,
            date: .now,
            tags: ["siri"]
        )
        try await repository.upsert(transaction)
        WidgetCenter.shared.reloadAllTimelines()
        Logger.intents.info("Added expense via intent")
        return .result(dialog: "Added \(entered.magnitude.formatted()) at \(payee) to \(resolved.category.displayName).")
    }
}

enum IntentFailure: Error, CustomLocalizedStringResourceConvertible {
    case noAccounts
    case unknownPeriod

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .noAccounts: "Add an account in Tally first."
        case .unknownPeriod: "Tally didn't recognise that period."
        }
    }
}
