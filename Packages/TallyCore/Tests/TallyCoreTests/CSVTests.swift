import Foundation
import Testing
@testable import TallyCore

@Suite("CSV parsing")
struct CSVParserTests {
    @Test("Parses a header and rows")
    func basic() throws {
        let table = try CSVParser().parse("Date,Payee,Amount\n2026-09-01,Coffee,-4.50\n2026-09-02,Salary,5400\n")
        #expect(table.header == ["Date", "Payee", "Amount"])
        #expect(table.rows == [["2026-09-01", "Coffee", "-4.50"], ["2026-09-02", "Salary", "5400"]])
    }

    @Test("Quoted fields may contain delimiters and doubled quotes")
    func quoting() throws {
        let table = try CSVParser().parse(#"a,b"# + "\n" + #""Joe's ""Famous"" Pizza, NYC",-18.00"#)
        #expect(table.rows == [[#"Joe's "Famous" Pizza, NYC"#, "-18.00"]])
    }

    @Test("Quoted fields may span lines")
    func embeddedNewline() throws {
        let table = try CSVParser().parse("payee,notes\nRent,\"line one\nline two\"\nGym,ok")
        #expect(table.rows.count == 2)
        #expect(table.rows[0][1] == "line one\nline two")
    }

    @Test("Handles a UTF-8 BOM, CRLF endings and blank lines")
    func bomAndCRLF() throws {
        let table = try CSVParser().parse("\u{FEFF}Date,Amount\r\n2026-01-01,1\r\n\r\n2026-01-02,2\r\n")
        #expect(table.header == ["Date", "Amount"])
        #expect(table.rows == [["2026-01-01", "1"], ["2026-01-02", "2"]])
    }

    @Test("Detects semicolon and tab delimiters")
    func delimiterDetection() throws {
        let semicolon = try CSVParser().parse("Datum;Empfänger;Betrag\n01.09.2026;Bäckerei;-3,20")
        #expect(semicolon.rows == [["01.09.2026", "Bäckerei", "-3,20"]])
        let tab = try CSVParser().parse("date\tpayee\tamount\n2026-09-01\tCafe, Bar\t-3")
        #expect(tab.rows == [["2026-09-01", "Cafe, Bar", "-3"]])
    }

    @Test("Reports the line an unterminated quote started on")
    func unterminatedQuote() {
        #expect(throws: CSVError.unterminatedQuote(line: 3)) {
            try CSVParser().parse("a,b\n1,2\n\"open,3\n4,5")
        }
    }

    @Test("An empty file is an error, not an empty table")
    func emptyFile() {
        #expect(throws: CSVError.empty) { try CSVParser().parse("") }
    }
}

@Suite("Amounts and import mapping")
struct CSVImportTests {
    @Test("Parses bank amount formats without Double", arguments: [
        ("(45.00)", "-45"), ("$1,234.56", "1234.56"), ("12.30-", "-12.3"), ("+5", "5"),
        ("12.00 DR", "-12"), ("7.25 CR", "7.25"), ("USD -9.99", "-9.99"),
    ])
    func periodDecimal(raw: String, expected: String) {
        #expect(AmountParser().parse(raw) == Fixture.decimal(expected))
    }

    @Test("Parses comma-decimal European formats")
    func commaDecimal() {
        let parser = AmountParser(decimalSeparator: .comma)
        #expect(parser.parse("1.234,56") == Fixture.decimal("1234.56"))
        #expect(parser.parse("€ -3,50") == Fixture.decimal("-3.5"))
        #expect(parser.parse("1 234,00") == Fixture.decimal("1234"))
    }

    @Test("Rejects text that is not an amount", arguments: ["", "abc", "1.2.3", "--"])
    func rejects(raw: String) {
        #expect(AmountParser().parse(raw) == nil)
    }

    @Test("Suggests split debit and credit columns and a day-first date format")
    func suggestsMapping() throws {
        let table = try CSVParser().parse("""
        Transaction Date,Description,Money Out,Money In,Reference
        28/09/2026,Tesco Metro,"12,40",,card
        30/09/2026,Payroll,,"2.100,00",BACS
        """)
        let mapping = try #require(CSVColumnMapping.suggested(for: table))
        #expect(mapping.date == 0)
        #expect(mapping.payee == 1)
        #expect(mapping.amount == .split(debit: 2, credit: 3))
        #expect(mapping.notes == 4)
        #expect(mapping.dateFormat == "dd/MM/yyyy")
        #expect(mapping.decimalSeparator == .comma)
    }

    @Test("Preview keeps good rows and reports bad ones by spreadsheet line")
    func previewIssues() throws {
        let table = try CSVParser().parse("date,payee,amount\n2026-09-01,Coffee,-4.50\nnot a date,Tea,-3\n2026-09-03,,-1\n2026-09-04,Lunch,lots")
        let mapping = CSVColumnMapping(date: 0, payee: 1, amount: .signed(2))
        let preview = CSVImporter(currency: .usd, timeZone: Fixture.newYork).preview(table, mapping: mapping)
        #expect(preview.rows.map(\.amount) == [Fixture.usd(-4_50)])
        #expect(preview.issues.map(\.line) == [3, 4, 5])
        #expect(preview.issues.first?.reason == .unreadableDate("not a date"))
        #expect(preview.issues.last?.reason == .unreadableAmount("lots"))
    }

    @Test("Card exports with positive purchases can be inverted")
    func invertSign() throws {
        let table = try CSVParser().parse("date,payee,amount\n09/14/2026,Amazon,23.99")
        let mapping = CSVColumnMapping(date: 0, payee: 1, amount: .signed(2), dateFormat: "MM/dd/yyyy", invertSign: true)
        let row = try #require(CSVImporter(currency: .usd, timeZone: Fixture.newYork).preview(table, mapping: mapping).rows.first)
        #expect(row.amount == Fixture.usd(-23_99))
        #expect(Fixture.calendar().component(.day, from: row.date) == 14)
    }
}
