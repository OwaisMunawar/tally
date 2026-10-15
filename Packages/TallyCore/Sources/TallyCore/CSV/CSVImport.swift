import Foundation

/// Which columns of a bank export hold which fields.
public struct CSVColumnMapping: Hashable, Sendable, Codable {
    public enum AmountColumns: Hashable, Sendable, Codable {
        /// One signed column.
        case signed(Int)
        /// Separate money-out and money-in columns, both unsigned.
        case split(debit: Int, credit: Int)
    }

    public var date: Int
    public var payee: Int
    public var amount: AmountColumns
    public var notes: Int?
    public var dateFormat: String
    public var decimalSeparator: AmountParser.DecimalSeparator
    /// Some card exports list purchases as positive numbers.
    public var invertSign: Bool

    public init(
        date: Int,
        payee: Int,
        amount: AmountColumns,
        notes: Int? = nil,
        dateFormat: String = "yyyy-MM-dd",
        decimalSeparator: AmountParser.DecimalSeparator = .period,
        invertSign: Bool = false
    ) {
        self.date = date
        self.payee = payee
        self.amount = amount
        self.notes = notes
        self.dateFormat = dateFormat
        self.decimalSeparator = decimalSeparator
        self.invertSign = invertSign
    }

    public static let supportedDateFormats = ["yyyy-MM-dd", "MM/dd/yyyy", "dd/MM/yyyy", "dd.MM.yyyy", "d MMM yyyy", "yyyy/MM/dd"]

    /// Guesses a mapping from header names and the first data rows.
    public static func suggested(for table: CSVTable) -> CSVColumnMapping? {
        let names = table.header.map { $0.lowercased() }
        func column(_ keywords: [String]) -> Int? {
            names.firstIndex { name in keywords.contains { name.contains($0) } }
        }
        guard let date = column(["date", "posted", "booking"]),
              let payee = column(["payee", "description", "merchant", "name", "details"]) else { return nil }

        let amount: AmountColumns
        if let debit = column(["debit", "money out", "withdrawal", "paid out"]),
           let credit = column(["credit", "money in", "deposit", "paid in"]) {
            amount = .split(debit: debit, credit: credit)
        } else if let signed = column(["amount", "value", "sum"]) {
            amount = .signed(signed)
        } else {
            return nil
        }

        let samples = table.rows.prefix(10).compactMap { $0.indices.contains(date) ? $0[date] : nil }
        let format = supportedDateFormats.first { format in
            let parser = CSVImporter.dateFormatter(format: format, timeZone: .gmt)
            return !samples.isEmpty && samples.allSatisfy { parser.date(from: $0.trimmingCharacters(in: .whitespaces)) != nil }
        } ?? "yyyy-MM-dd"

        let amountSamples = table.rows.prefix(10).flatMap { row -> [String] in
            switch amount {
            case .signed(let index): row.indices.contains(index) ? [row[index]] : []
            case .split(let debit, let credit): [debit, credit].filter(row.indices.contains).map { row[$0] }
            }
        }
        let usesCommaDecimal = amountSamples.contains { $0.range(of: #",\d{2}$"#, options: .regularExpression) != nil }

        return CSVColumnMapping(
            date: date,
            payee: payee,
            amount: amount,
            notes: column(["memo", "note", "reference"]),
            dateFormat: format,
            decimalSeparator: usesCommaDecimal ? .comma : .period
        )
    }
}

public struct ImportedRow: Identifiable, Hashable, Sendable {
    public let line: Int
    public let date: Date
    public let payee: String
    public let amount: Money
    public let notes: String
    public var id: Int { line }

    public init(line: Int, date: Date, payee: String, amount: Money, notes: String) {
        self.line = line
        self.date = date
        self.payee = payee
        self.amount = amount
        self.notes = notes
    }
}

public struct ImportIssue: Error, Identifiable, Hashable, Sendable {
    public enum Reason: Hashable, Sendable {
        case missingColumn(Int)
        case unreadableDate(String)
        case unreadableAmount(String)
        case emptyPayee
    }

    public let line: Int
    public let reason: Reason
    public var id: Int { line }
}

public struct ImportPreview: Hashable, Sendable {
    public let rows: [ImportedRow]
    public let issues: [ImportIssue]
}

/// Turns a parsed table plus a mapping into rows ready to save, collecting
/// per-line problems instead of failing the whole file.
public struct CSVImporter: Sendable {
    public let currency: CurrencyCode
    public let timeZone: TimeZone

    public init(currency: CurrencyCode, timeZone: TimeZone) {
        self.currency = currency
        self.timeZone = timeZone
    }

    public func preview(_ table: CSVTable, mapping: CSVColumnMapping) -> ImportPreview {
        let formatter = Self.dateFormatter(format: mapping.dateFormat, timeZone: timeZone)
        let amounts = AmountParser(decimalSeparator: mapping.decimalSeparator)
        var rows: [ImportedRow] = []
        var issues: [ImportIssue] = []

        for (offset, row) in table.rows.enumerated() {
            // Line numbers are 1-based and the header is line 1, matching what a spreadsheet shows.
            let line = offset + 2
            switch convert(row, line: line, mapping: mapping, formatter: formatter, amounts: amounts) {
            case .success(let imported): rows.append(imported)
            case .failure(let issue): issues.append(issue)
            }
        }
        return ImportPreview(rows: rows, issues: issues)
    }

    private func convert(
        _ row: [String],
        line: Int,
        mapping: CSVColumnMapping,
        formatter: DateFormatter,
        amounts: AmountParser
    ) -> Result<ImportedRow, ImportIssue> {
        func cell(_ index: Int) -> String? {
            row.indices.contains(index) ? row[index].trimmingCharacters(in: .whitespacesAndNewlines) : nil
        }
        guard let rawDate = cell(mapping.date) else { return .failure(ImportIssue(line: line, reason: .missingColumn(mapping.date))) }
        guard let date = formatter.date(from: rawDate) else { return .failure(ImportIssue(line: line, reason: .unreadableDate(rawDate))) }
        guard let payee = cell(mapping.payee) else { return .failure(ImportIssue(line: line, reason: .missingColumn(mapping.payee))) }
        guard !payee.isEmpty else { return .failure(ImportIssue(line: line, reason: .emptyPayee)) }

        let value: Decimal
        switch amount(in: row, line: line, columns: mapping.amount, parser: amounts) {
        case .success(let parsed): value = parsed
        case .failure(let issue): return .failure(issue)
        }

        guard let money = try? Money(mapping.invertSign ? -value : value, currency: currency) else {
            return .failure(ImportIssue(line: line, reason: .unreadableAmount("\(value)")))
        }
        return .success(ImportedRow(line: line, date: date, payee: payee, amount: money, notes: mapping.notes.flatMap(cell) ?? ""))
    }

    private func amount(in row: [String], line: Int, columns: CSVColumnMapping.AmountColumns, parser: AmountParser) -> Result<Decimal, ImportIssue> {
        func cell(_ index: Int) -> String? {
            guard row.indices.contains(index) else { return nil }
            let value = row[index].trimmingCharacters(in: .whitespacesAndNewlines)
            return value.isEmpty ? nil : value
        }
        func parse(_ raw: String) -> Result<Decimal, ImportIssue> {
            parser.parse(raw).map { .success($0) } ?? .failure(ImportIssue(line: line, reason: .unreadableAmount(raw)))
        }
        switch columns {
        case .signed(let index):
            guard row.indices.contains(index) else { return .failure(ImportIssue(line: line, reason: .missingColumn(index))) }
            return parse(cell(index) ?? "")
        case .split(let debit, let credit):
            // Exactly one of the two columns carries the amount; its column decides the sign.
            if let out = cell(debit) { return parse(out).map { -$0.magnitude } }
            if let into = cell(credit) { return parse(into).map(\.magnitude) }
            return .failure(ImportIssue(line: line, reason: .unreadableAmount("")))
        }
    }

    static func dateFormatter(format: String, timeZone: TimeZone) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timeZone
        formatter.dateFormat = format
        formatter.isLenient = false
        return formatter
    }
}
