import AppIntents

/// Opens Tally on the quick-add sheet. Used by the Control Center control,
/// the widget's add button and Shortcuts.
struct QuickAddIntent: AppIntent {
    static let title: LocalizedStringResource = "Quick Add Expense"
    static let description = IntentDescription("Open Tally ready to add an expense.")
    static let supportedModes: IntentModes = .foreground(.immediate)

    @MainActor
    func perform() async throws -> some IntentResult {
        PendingRoute.request(.quickAdd)
        return .result()
    }
}

/// "Show my budget in Tally."
struct ShowBudgetIntent: AppIntent {
    static let title: LocalizedStringResource = "Show Budget"
    static let description = IntentDescription("Open your monthly budgets in Tally.")
    static let supportedModes: IntentModes = .foreground(.immediate)

    @MainActor
    func perform() async throws -> some IntentResult {
        PendingRoute.request(.budgets)
        return .result()
    }
}
