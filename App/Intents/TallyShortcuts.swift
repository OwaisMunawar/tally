import AppIntents

/// Siri phrases and Shortcuts tiles. Lives in the app target only; the widget
/// extension compiles the intents but must not register a second provider.
struct TallyShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddExpenseIntent(),
            phrases: [
                "Add an expense in \(.applicationName)",
                "Log spending in \(.applicationName)",
            ],
            shortTitle: "Add Expense",
            systemImageName: "plus.circle.fill"
        )
        AppShortcut(
            intent: SpendQueryIntent(),
            phrases: [
                "How much did I spend on \(\.$category) in \(.applicationName)",
                "\(.applicationName) spending on \(\.$category)",
            ],
            shortTitle: "Spending",
            systemImageName: "chart.bar.fill"
        )
        AppShortcut(
            intent: ShowBudgetIntent(),
            phrases: [
                "Show my budget in \(.applicationName)",
                "Open \(.applicationName) budgets",
            ],
            shortTitle: "Budgets",
            systemImageName: "chart.pie.fill"
        )
    }

    static let shortcutTileColor: ShortcutTileColor = .blue
}
