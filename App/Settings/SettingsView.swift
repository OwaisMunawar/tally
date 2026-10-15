import SwiftUI
import TallyCore
import TallyIntelligence
import TallyUI

struct SettingsView: View {
    @Environment(LedgerStore.self) private var ledger
    @Environment(PlusStore.self) private var plus
    @Environment(AppLock.self) private var lock
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss
    @State private var confirmingDemo = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Label(plus.isPlus ? "Tally Plus is active" : "Tally Plus", systemImage: "sparkles")
                        Spacer()
                        if !plus.isPlus {
                            Button("Upgrade") { router.sheet = .store }.buttonStyle(.glassProminent)
                        }
                    }
                } footer: {
                    Text("Plus adds Ask Tally, CSV import and unlimited budgets.")
                }

                Section("Money") {
                    NavigationLink("Exchange rates") { ExchangeRatesView() }
                    LabeledContent("Base currency", value: ledger.baseCurrency.rawValue)
                    NavigationLink("Categorisation rules") { RulesView() }
                }

                Section {
                    Toggle("Require \(AppLock.biometryName)", isOn: Binding(
                        get: { lock.isEnabled },
                        set: { enabled in Task { await lock.setEnabled(enabled) } }
                    ))
                    if let message = lock.errorMessage {
                        Text(message).font(.footnote).foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Privacy")
                } footer: {
                    Text("Your ledger lives in an encrypted on-device database. Tally has no server, no analytics and no account.")
                }

                Section {
                    LabeledContent("Apple Intelligence", value: AssistantAvailability.current.isAvailable ? "Ready" : "Unavailable")
                    if !AssistantAvailability.current.isAvailable {
                        Text(AssistantAvailability.current.explanation).font(.footnote).foregroundStyle(.secondary)
                    }
                } header: {
                    Text("On-device AI")
                }

                Section("Data") {
                    Button("Load demo data", systemImage: "wand.and.stars") { confirmingDemo = true }
                }

                Section {
                    LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done", systemImage: "checkmark") { dismiss() } }
            }
            .confirmationDialog("Replace everything with demo data?", isPresented: $confirmingDemo, titleVisibility: .visible) {
                Button("Replace with demo data", role: .destructive) { Task { await ledger.seedDemoData() } }
            } message: {
                Text("Six months of fictional transactions across three accounts. Your current data is removed.")
            }
        }
    }
}

struct ExchangeRatesView: View {
    @Environment(LedgerStore.self) private var ledger
    @State private var drafts: [CurrencyCode: Decimal] = [:]
    @State private var newCode = ""
    @State private var error: String?

    var body: some View {
        Form {
            Section {
                ForEach(ledger.data.rates.currencies.filter { $0 != ledger.baseCurrency }, id: \.self) { code in
                    HStack {
                        Text("1 \(code.rawValue) =")
                        TextField("Rate", value: binding(for: code), format: .number.precision(.fractionLength(0...6)))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        Text(ledger.baseCurrency.rawValue).foregroundStyle(.secondary)
                    }
                }
                HStack {
                    TextField("Add currency (e.g. GBP)", text: $newCode)
                        .textInputAutocapitalization(.characters)
                    Button("Add") { add() }.disabled(!CurrencyCode(newCode).isValid)
                }
            } footer: {
                Text("Tally never fetches rates from the internet. Enter the rates you want totals to use; last updated \(ledger.data.rates.updatedAt.formatted(date: .abbreviated, time: .omitted)).")
            }
            if let error {
                Text(error).foregroundStyle(TallyTheme.negative)
            }
        }
        .navigationTitle("Exchange Rates")
        .toolbar {
            Button("Save") { Task { await save() } }.disabled(drafts.isEmpty)
        }
    }

    private func binding(for code: CurrencyCode) -> Binding<Decimal> {
        Binding(get: { drafts[code] ?? ledger.data.rates.rate(for: code) ?? 1 }, set: { drafts[code] = $0 })
    }

    private func add() {
        drafts[CurrencyCode(newCode)] = 1
        newCode = ""
        Task { await save() }
    }

    private func save() async {
        var table = ledger.data.rates
        do {
            for (code, rate) in drafts { try table.setRate(rate, for: code) }
            await ledger.save(table)
            drafts = [:]
            error = nil
        } catch {
            self.error = "Rates must be greater than zero."
        }
    }
}

struct RulesView: View {
    @Environment(LedgerStore.self) private var ledger

    var body: some View {
        List {
            Section {
                if ledger.data.rules.isEmpty {
                    Text("Correct a transaction's category with \"Remember for this payee\" on and Tally learns a rule.")
                        .foregroundStyle(.secondary)
                }
                ForEach(ledger.data.rules) { rule in
                    HStack {
                        Text(rule.keyword)
                        Spacer()
                        Label(rule.category.displayName, systemImage: rule.category.systemImage)
                            .foregroundStyle(TallyTheme.color(for: rule.category))
                    }
                }
                .onDelete { offsets in
                    let rules = offsets.map { ledger.data.rules[$0] }
                    Task { for rule in rules { await ledger.deleteRule(rule) } }
                }
            } header: {
                Text("Learned from your corrections")
            } footer: {
                Text("Learned rules run before Apple Intelligence, so your corrections always win.")
            }
            Section("Built in") {
                Text("\(RuleBasedCategorizer.defaultRules.count) keyword rules cover common merchants when Apple Intelligence is unavailable.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Rules")
    }
}
