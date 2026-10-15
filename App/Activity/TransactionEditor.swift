import SwiftUI
import TallyCore
import TallyUI

/// Create or edit a transaction. As the payee is typed, the hybrid categoriser
/// proposes a category and shows where the suggestion came from.
struct TransactionEditor: View {
    enum Mode {
        case create
        case edit(LedgerTransaction)
    }

    enum Repeat: String, CaseIterable, Identifiable {
        case never, weekly, monthly
        var id: String { rawValue }
    }

    let mode: Mode
    @Environment(LedgerStore.self) private var ledger
    @Environment(CategorizationService.self) private var categorization
    @Environment(\.dismiss) private var dismiss

    @State private var amount: Decimal?
    @State private var isIncome = false
    @State private var payee = ""
    @State private var accountID: UUID?
    @State private var category: TransactionCategory = .other
    @State private var source: CategorizationSource = .uncategorized
    @State private var date = Date.now
    @State private var notes = ""
    @State private var tags = ""
    @State private var repeatRule: Repeat = .never
    @State private var userPickedCategory = false
    @FocusState private var amountFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Amount", value: $amount, format: .number.precision(.fractionLength(0...2)))
                        .keyboardType(.decimalPad)
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .focused($amountFocused)
                        .accessibilityLabel("Amount in \(selectedAccount?.currency.rawValue ?? "")")
                    Picker("Type", selection: $isIncome) {
                        Text("Expense").tag(false)
                        Text("Income").tag(true)
                    }
                    .pickerStyle(.segmented)
                }
                Section {
                    TextField("Payee", text: $payee)
                        .textInputAutocapitalization(.words)
                    Picker("Account", selection: $accountID) {
                        ForEach(ledger.accounts) { account in
                            Text("\(account.name) (\(account.currency.rawValue))").tag(Optional(account.id))
                        }
                    }
                    DatePicker("Date", selection: $date)
                }
                Section {
                    Picker("Category", selection: categorySelection) {
                        ForEach(TransactionCategory.allCases) { category in
                            Label(category.displayName, systemImage: category.systemImage).tag(category)
                        }
                    }
                    if !userPickedCategory, source != .uncategorized {
                        LabeledContent("Suggested by") { CategorizationBadge(source) }
                    }
                } header: {
                    Text("Category")
                } footer: {
                    if !categorization.availability.isAvailable {
                        Text("Using keyword rules. \(categorization.availability.explanation)")
                    }
                }
                Section("More") {
                    TextField("Notes", text: $notes, axis: .vertical)
                    TextField("Tags, separated by commas", text: $tags)
                    if case .create = mode {
                        Picker("Repeat", selection: $repeatRule) {
                            ForEach(Repeat.allCases) { Text($0.rawValue.capitalized).tag($0) }
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Transaction" : "New Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", systemImage: "checkmark") { Task { await save() } }
                        .buttonStyle(.glassProminent)
                        .disabled(!canSave)
                }
            }
            .task(id: payee) { await suggestCategory() }
            .onAppear(perform: populate)
        }
    }

    private var isEditing: Bool {
        if case .edit = mode { true } else { false }
    }

    private var selectedAccount: Account? {
        accountID.flatMap(ledger.account(id:)) ?? ledger.accounts.first
    }

    private var canSave: Bool {
        (amount ?? 0) > 0 && !payee.trimmingCharacters(in: .whitespaces).isEmpty && selectedAccount != nil
    }

    private var categorySelection: Binding<TransactionCategory> {
        Binding(get: { category }, set: { category = $0; userPickedCategory = true; source = .manual })
    }

    private func populate() {
        guard case .edit(let transaction) = mode else {
            accountID = ledger.accounts.first { $0.kind == .card }?.id ?? ledger.accounts.first?.id
            amountFocused = true
            return
        }
        amount = transaction.amount.magnitude.amount
        isIncome = transaction.amount.isPositive
        payee = transaction.payee
        accountID = transaction.accountID
        category = transaction.category
        source = transaction.categorization
        date = transaction.date
        notes = transaction.notes
        tags = transaction.tags.joined(separator: ", ")
        userPickedCategory = true
    }

    /// Debounced so the model isn't asked about every keystroke.
    private func suggestCategory() async {
        guard !userPickedCategory, let account = selectedAccount else { return }
        try? await Task.sleep(for: .milliseconds(450))
        guard !Task.isCancelled else { return }
        let probe = Money(minorUnits: isIncome ? 1 : -1, currency: account.currency)
        if let suggestion = await categorization.suggest(payee: payee, amount: probe, rules: ledger.data.rules), !Task.isCancelled {
            category = suggestion.category
            source = suggestion.source
        }
    }

    private func save() async {
        guard let account = selectedAccount, let amount,
              let magnitude = try? Money(amount, currency: account.currency) else { return }
        let signed = isIncome ? magnitude.magnitude : magnitude.magnitude.negated
        let tagList = tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let name = payee.trimmingCharacters(in: .whitespaces)

        var transaction: LedgerTransaction
        if case .edit(let existing) = mode {
            transaction = existing
        } else {
            transaction = LedgerTransaction(accountID: account.id, payee: name, amount: signed, category: category, date: date)
        }
        transaction.accountID = account.id
        transaction.payee = name
        transaction.amount = signed
        transaction.category = category
        transaction.categorization = userPickedCategory ? .manual : source
        transaction.date = date
        transaction.notes = notes
        transaction.tags = tagList

        if repeatRule != .never {
            let rule: RecurrenceRule = repeatRule == .weekly ? .weekly : .monthly
            let template = RecurringTransaction(accountID: account.id, payee: name, amount: signed, category: category, rule: rule, startDate: date)
            await ledger.save(template)
        } else {
            await ledger.save(transaction)
        }
        dismiss()
    }
}
