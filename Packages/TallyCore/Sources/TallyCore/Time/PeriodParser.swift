import Foundation

/// A period resolved from loose text, with the label Tally shows back to the user.
public struct ResolvedPeriod: Hashable, Sendable {
    public let range: DateRange
    public let label: String

    public init(range: DateRange, label: String) {
        self.range = range
        self.label = label
    }
}

/// Turns the period strings that tools receive into concrete date ranges.
///
/// The on-device model is told to send tokens like `this_month` or `2026-09`,
/// but small models paraphrase, so this also accepts month names ("September",
/// "sep 2026") and resolves a bare month name to its most recent occurrence
/// that is not in the future.
public struct PeriodParser: Sendable {
    public let calendar: Calendar
    public let now: Date
    public let locale: Locale

    public init(calendar: Calendar, now: Date, locale: Locale = Locale(identifier: "en_US_POSIX")) {
        self.calendar = calendar
        self.now = now
        self.locale = locale
    }

    public func parse(_ text: String) -> ResolvedPeriod? {
        let token = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
        guard !token.isEmpty else { return nil }

        if let range = keywordRange(token) { return resolved(range) }
        if let range = isoMonth(token) ?? isoYear(token) ?? namedMonth(token) { return resolved(range) }
        return nil
    }

    private func resolved(_ range: DateRange) -> ResolvedPeriod {
        ResolvedPeriod(range: range, label: range.label(calendar: calendar, locale: Locale(identifier: "en_US")))
    }

    private func keywordRange(_ token: String) -> DateRange? {
        let thisMonth = DateRange.month(containing: now, calendar: calendar)
        switch token {
        case "this_month", "current_month", "month":
            return thisMonth
        case "last_month", "previous_month":
            return thisMonth.previousMonth(calendar: calendar)
        case "this_year", "current_year", "year", "ytd", "year_to_date":
            return .year(containing: now, calendar: calendar)
        case "last_year", "previous_year":
            let lastYear = calendar.date(byAdding: .year, value: -1, to: now) ?? now
            return .year(containing: lastYear, calendar: calendar)
        case "last_7_days", "this_week", "past_week", "last_week":
            return .lastDays(7, endingOn: now, calendar: calendar)
        case "last_30_days", "past_month":
            return .lastDays(30, endingOn: now, calendar: calendar)
        case "last_90_days", "last_3_months", "last_three_months":
            let start = calendar.date(byAdding: .month, value: -2, to: thisMonth.start) ?? thisMonth.start
            return DateRange(start: start, end: thisMonth.end)
        case "last_6_months", "last_six_months":
            let start = calendar.date(byAdding: .month, value: -5, to: thisMonth.start) ?? thisMonth.start
            return DateRange(start: start, end: thisMonth.end)
        default:
            return nil
        }
    }

    private func isoMonth(_ token: String) -> DateRange? {
        let parts = token.split(separator: "-")
        guard parts.count >= 2, let year = Int(parts[0]), let month = Int(parts[1]), parts[0].count == 4 else { return nil }
        return .month(year: year, month: month, calendar: calendar)
    }

    private func isoYear(_ token: String) -> DateRange? {
        guard token.count == 4, let year = Int(token),
              let date = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) else { return nil }
        return .year(containing: date, calendar: calendar)
    }

    private func namedMonth(_ token: String) -> DateRange? {
        let words = token.split(separator: "_").map(String.init)
        guard let first = words.first, let month = monthNumber(first) else { return nil }
        if words.count > 1, let year = Int(words[1]) {
            return .month(year: year, month: month, calendar: calendar)
        }
        let currentYear = calendar.component(.year, from: now)
        let currentMonth = calendar.component(.month, from: now)
        let year = month > currentMonth ? currentYear - 1 : currentYear
        return .month(year: year, month: month, calendar: calendar)
    }

    private func monthNumber(_ word: String) -> Int? {
        var symbolCalendar = calendar
        symbolCalendar.locale = locale
        let full = symbolCalendar.monthSymbols.map { $0.lowercased() }
        let short = symbolCalendar.shortMonthSymbols.map { $0.lowercased().trimmingCharacters(in: .punctuationCharacters) }
        if let index = full.firstIndex(of: word) ?? short.firstIndex(of: word) { return index + 1 }
        if word.count >= 3, let index = full.firstIndex(where: { $0.hasPrefix(word) }) { return index + 1 }
        return nil
    }
}
