import AppIntents
import SwiftUI
import WidgetKit

/// A Control Center, Lock Screen and Action button control that opens Tally
/// straight into the add-expense sheet.
struct QuickAddControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: WidgetKinds.quickAddControl) {
            ControlWidgetButton(action: QuickAddIntent()) {
                Label("Add Expense", systemImage: "plus.circle.fill")
            }
        }
        .displayName("Add Expense")
        .description("Log a purchase in Tally.")
    }
}
