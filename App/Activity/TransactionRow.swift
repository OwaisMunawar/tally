import SwiftUI
import TallyCore
import TallyUI

struct TransactionRow: View {
    let transaction: LedgerTransaction
    @Environment(LedgerStore.self) private var ledger

    var body: some View {
        HStack(spacing: TallyTheme.Spacing.medium) {
            CategoryIcon(transaction.category)
            VStack(alignment: .leading, spacing: 3) {
                Text(transaction.payee).font(.body.weight(.medium)).lineLimit(1)
                HStack(spacing: 6) {
                    Text(transaction.category.displayName).lineLimit(1)
                    CategorizationBadge(transaction.categorization)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: TallyTheme.Spacing.small)
            VStack(alignment: .trailing, spacing: 3) {
                MoneyText(transaction.amount, style: .signed)
                if transaction.amount.currency != ledger.baseCurrency, let engine = ledger.engine {
                    Text(engine.baseAmount(of: transaction).formatted())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}
