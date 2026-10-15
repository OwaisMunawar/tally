import Foundation

public enum CSVError: Error, Equatable, Sendable {
    case empty
    case unterminatedQuote(line: Int)
}

public struct CSVTable: Hashable, Sendable {
    public let header: [String]
    public let rows: [[String]]

    public init(header: [String], rows: [[String]]) {
        self.header = header
        self.rows = rows
    }
}

/// RFC 4180 parser with the tolerance real bank exports need: a UTF-8 BOM,
/// CRLF or LF line endings, quoted fields containing delimiters, doubled
/// quotes and line breaks, blank lines, and semicolon or tab delimiters
/// (common in European exports, where the comma is the decimal separator).
public struct CSVParser: Sendable {
    public let delimiter: Character?

    /// Pass `nil` to detect the delimiter from the header line.
    public init(delimiter: Character? = nil) {
        self.delimiter = delimiter
    }

    public func parse(_ text: String) throws(CSVError) -> CSVTable {
        var body = Substring(text)
        if body.first == "\u{FEFF}" { body = body.dropFirst() }
        let separator = delimiter ?? Self.detectDelimiter(in: body)

        var records: [[String]] = []
        var record: [String] = []
        var field = ""
        var inQuotes = false
        var fieldWasQuoted = false
        var line = 1
        var quoteOpenedOnLine = 1
        var iterator = body.makeIterator()
        var pending: Character? = iterator.next()

        func endRecord() {
            record.append(field)
            // A line holding a single empty unquoted field is a blank line, not data.
            if !(record.count == 1 && record[0].isEmpty && !fieldWasQuoted) { records.append(record) }
            record = []
            field = ""
            fieldWasQuoted = false
        }

        while let character = pending {
            pending = iterator.next()
            if inQuotes {
                if character == "\"" {
                    if pending == "\"" {
                        field.append("\"")
                        pending = iterator.next()
                    } else {
                        inQuotes = false
                    }
                } else {
                    if character.isNewline { line += 1 }
                    field.append(character)
                }
                continue
            }
            switch character {
            case "\"" where field.isEmpty && !fieldWasQuoted:
                inQuotes = true
                fieldWasQuoted = true
                quoteOpenedOnLine = line
            case separator:
                record.append(field)
                field = ""
                fieldWasQuoted = false
            case _ where character.isNewline:
                // Swift treats "\r\n" as a single Character, so CRLF needs no special case.
                line += 1
                endRecord()
            default:
                field.append(character)
            }
        }
        if inQuotes { throw .unterminatedQuote(line: quoteOpenedOnLine) }
        if !field.isEmpty || !record.isEmpty || fieldWasQuoted { endRecord() }

        guard let header = records.first else { throw .empty }
        return CSVTable(
            header: header.map { $0.trimmingCharacters(in: .whitespaces) },
            rows: Array(records.dropFirst())
        )
    }

    static func detectDelimiter(in text: Substring) -> Character {
        let candidates: [Character] = [",", ";", "\t", "|"]
        var counts: [Character: Int] = [:]
        var inQuotes = false
        for character in text {
            if character == "\"" { inQuotes.toggle() }
            if character.isNewline && !inQuotes { break }
            if !inQuotes && candidates.contains(character) { counts[character, default: 0] += 1 }
        }
        return candidates.max { (counts[$0] ?? 0) < (counts[$1] ?? 0) }.flatMap { (counts[$0] ?? 0) > 0 ? $0 : nil } ?? ","
    }
}
