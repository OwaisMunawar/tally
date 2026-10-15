import SwiftUI
import TallyCore
import TallyUI
import UniformTypeIdentifiers

/// Pick a bank export, map its columns, preview, then import.
struct CSVImportView: View {
    @Environment(LedgerStore.self) private var ledger
    @Environment(CategorizationService.self) private var categorization
    @Environment(\.dismiss) private var dismiss

    @State private var isPickingFile = false
    @State private var fileName: String?
    @State private var table: CSVTable?
    @State private var mapping: CSVColumnMapping?
    @State private var accountID: UUID?
    @State private var errorMessage: String?
    @State private var isImporting = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button(fileName ?? "Choose a CSV file", systemImage: "doc.badge.plus") { isPickingFile = true }
                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle").foregroundStyle(TallyTheme.negative)
                    }
                } footer: {
                    Text("The file is read on this iPhone and never uploaded.")
                }

                if let table, mapping != nil {
                    mappingSection(table)
                    previewSection
                }
            }
            .navigationTitle("Import CSV")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import", systemImage: "checkmark") { Task { await runImport() } }
                        .buttonStyle(.glassProminent)
                        .disabled((preview?.rows.isEmpty ?? true) || isImporting)
                }
            }
            .fileImporter(isPresented: $isPickingFile, allowedContentTypes: [.commaSeparatedText, .plainText]) { result in
                load(result)
            }
            .onAppear { accountID = ledger.accounts.first?.id }
        }
    }

    private var account: Account? {
        accountID.flatMap(ledger.account(id:))
    }

    private var preview: ImportPreview? {
        guard let table, let mapping, let account else { return nil }
        return CSVImporter(currency: account.currency, timeZone: ledger.calendar.timeZone).preview(table, mapping: mapping)
    }

    @ViewBuilder
    private func mappingSection(_ table: CSVTable) -> some View {
        Section("Columns") {
            Picker("Account", selection: $accountID) {
                ForEach(ledger.accounts) { Text($0.name).tag(Optional($0.id)) }
            }
            columnPicker("Date", keyPath: \.date, header: table.header)
            columnPicker("Payee", keyPath: \.payee, header: table.header)
            Picker("Amount", selection: amountBinding) {
                ForEach(table.header.indices, id: \.self) { index in
                    Text(table.header[index]).tag(CSVColumnMapping.AmountColumns.signed(index))
                }
                if case .split(let debit, let credit) = mapping?.amount {
                    Text("\(table.header[debit]) / \(table.header[credit])").tag(CSVColumnMapping.AmountColumns.split(debit: debit, credit: credit))
                }
            }
            Picker("Date format", selection: binding(\.dateFormat, default: "yyyy-MM-dd")) {
                ForEach(CSVColumnMapping.supportedDateFormats, id: \.self) { Text($0).tag($0) }
            }
            Picker("Decimal separator", selection: binding(\.decimalSeparator, default: .period)) {
                Text("1,234.56").tag(AmountParser.DecimalSeparator.period)
                Text("1.234,56").tag(AmountParser.DecimalSeparator.comma)
            }
            Toggle("Purchases are positive", isOn: binding(\.invertSign, default: false))
        }
    }

    @ViewBuilder
    private var previewSection: some View {
        if let preview {
            Section {
                ForEach(preview.rows.prefix(8)) { row in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(row.payee).lineLimit(1)
                            Text(row.date, format: .dateTime.day().month().year()).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        MoneyText(row.amount, style: .signed)
                    }
                }
                ForEach(preview.issues.prefix(5)) { issue in
                    Label("Line \(issue.line): \(describe(issue.reason))", systemImage: "exclamationmark.circle")
                        .font(.footnote)
                        .foregroundStyle(TallyTheme.warning)
                }
            } header: {
                Text("Preview")
            } footer: {
                Text("\(preview.rows.count) rows ready, \(preview.issues.count) skipped. Categories are suggested on import.")
            }
        }
    }

    private func columnPicker(_ title: String, keyPath: WritableKeyPath<CSVColumnMapping, Int>, header: [String]) -> some View {
        Picker(title, selection: binding(keyPath, default: 0)) {
            ForEach(header.indices, id: \.self) { Text(header[$0]).tag($0) }
        }
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<CSVColumnMapping, Value>, default value: Value) -> Binding<Value> {
        Binding(get: { mapping?[keyPath: keyPath] ?? value }, set: { mapping?[keyPath: keyPath] = $0 })
    }

    private var amountBinding: Binding<CSVColumnMapping.AmountColumns> {
        binding(\.amount, default: .signed(0))
    }

    private func load(_ result: Result<URL, any Error>) {
        do {
            let url = try result.get()
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            let text = try String(contentsOf: url, encoding: .utf8)
            let parsed = try CSVParser().parse(text)
            table = parsed
            mapping = CSVColumnMapping.suggested(for: parsed)
                ?? CSVColumnMapping(date: 0, payee: min(1, parsed.header.count - 1), amount: .signed(min(2, parsed.header.count - 1)))
            fileName = url.lastPathComponent
            errorMessage = nil
        } catch let error as CSVError {
            errorMessage = switch error {
            case .empty: "That file is empty."
            case .unterminatedQuote(let line): "A quote opened on line \(line) is never closed."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func runImport() async {
        guard let preview, let account else { return }
        isImporting = true
        let categorizer = categorization.makeCategorizer(rules: ledger.data.rules)
        _ = await ledger.importRows(preview.rows, into: account, categorizer: categorizer)
        isImporting = false
        dismiss()
    }

    private func describe(_ reason: ImportIssue.Reason) -> String {
        switch reason {
        case .missingColumn(let index): "missing column \(index + 1)"
        case .unreadableDate(let text): "can't read date \"\(text)\""
        case .unreadableAmount(let text): "can't read amount \"\(text)\""
        case .emptyPayee: "no payee"
        }
    }
}
