import SwiftUI
import TallyCore
import TallyUI

struct TransactionDetailView: View {
    let transactionID: UUID
    @Environment(LedgerStore.self) private var ledger
    @Environment(\.dismiss) private var dismiss
    @State private var rememberPayee = true
    @State private var isEditing = false

    private var transaction: LedgerTransaction? {
        ledger.data.transactions.first { $0.id == transactionID }
    }

    var body: some View {
        if let transaction {
            Form {
                Section {
                    VStack(spacing: TallyTheme.Spacing.small) {
                        CategoryIcon(transaction.category, size: 56)
                        Text(transaction.payee).font(.title3.weight(.semibold)).multilineTextAlignment(.center)
                        MoneyText(transaction.amount, style: .hero)
                        Text(transaction.date, format: .dateTime.weekday(.wide).day().month(.wide).year().hour().minute())
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }

                Section {
                    Picker("Category", selection: categoryBinding(for: transaction)) {
                        ForEach(TransactionCategory.allCases) { category in
                            Label(category.displayName, systemImage: category.systemImage).tag(category)
                        }
                    }
                    LabeledContent("Categorised by") {
                        CategorizationBadge(transaction.categorization)
                    }
                    Toggle("Remember for this payee", isOn: $rememberPayee)
                } header: {
                    Text("Category")
                } footer: {
                    Text(provenance(for: transaction.categorization))
                }

                Section("Details") {
                    if let account = ledger.account(id: transaction.accountID) {
                        LabeledContent("Account", value: account.name)
                    }
                    if transaction.amount.currency != ledger.baseCurrency, let engine = ledger.engine {
                        LabeledContent("In \(ledger.baseCurrency.rawValue)", value: engine.baseAmount(of: transaction).formatted())
                    }
                    if !transaction.notes.isEmpty {
                        LabeledContent("Notes", value: transaction.notes)
                    }
                    if !transaction.tags.isEmpty {
                        LabeledContent("Tags", value: transaction.tags.map { "#\($0)" }.joined(separator: " "))
                    }
                    if transaction.recurringID != nil {
                        Label("Repeats automatically", systemImage: "repeat")
                    }
                }

                Section {
                    Button("Delete Transaction", role: .destructive) {
                        Task {
                            await ledger.delete(transaction)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button("Edit") { isEditing = true }
            }
            .sheet(isPresented: $isEditing) {
                TransactionEditor(mode: .edit(transaction))
            }
        } else {
            ContentUnavailableView("Transaction deleted", systemImage: "trash")
        }
    }

    private func categoryBinding(for transaction: LedgerTransaction) -> Binding<TransactionCategory> {
        Binding(
            get: { transaction.category },
            set: { newValue in
                guard newValue != transaction.category else { return }
                Task { await ledger.recategorize(transaction, as: newValue, learn: rememberPayee) }
            }
        )
    }

    private func provenance(for source: CategorizationSource) -> String {
        switch source {
        case .manual:
            "You chose this category."
        case .rule(let keyword, let learned):
            learned ? "Matched \"\(keyword)\", a rule Tally learned from one of your corrections."
                    : "Matched the built-in keyword \"\(keyword)\"."
        case .model(let confidence):
            "Suggested on this iPhone by Apple Intelligence with \(confidence)% confidence. Correct it and Tally will remember."
        case .uncategorized:
            "Imported without a category. Pick one and Tally will remember this payee."
        }
    }
}
