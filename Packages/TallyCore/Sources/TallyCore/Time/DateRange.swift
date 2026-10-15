import Foundation

/// A half-open interval `[start, end)`.
///
/// Half-open ranges tile without gaps or overlaps, so "September" and
/// "October" never both claim a transaction stamped at midnight on the 1st.
public struct DateRange: Hashable, Sendable, Codable {
    public let start: Date
    public let end: Date

    public init(start: Date, end: Date) {
        self.start = min(start, end)
        self.end = max(start, end)
    }

    public func contains(_ date: Date) -> Bool {
        date >= start && date < end
    }

    public var duration: TimeInterval {
        end.timeIntervalSince(start)
    }

    /// The calendar month containing `date`, in the calendar's time zone.
    public static func month(containing date: Date, calendar: Calendar) -> DateRange {
        guard let interval = calendar.dateInterval(of: .month, for: date) else {
            return DateRange(start: date, end: date)
        }
        return DateRange(start: interval.start, end: interval.end)
    }

    public static func year(containing date: Date, calendar: Calendar) -> DateRange {
        guard let interval = calendar.dateInterval(of: .year, for: date) else {
            return DateRange(start: date, end: date)
        }
        return DateRange(start: interval.start, end: interval.end)
    }

    public static func month(year: Int, month: Int, calendar: Calendar) -> DateRange? {
        guard (1...12).contains(month),
              let date = calendar.date(from: DateComponents(year: year, month: month, day: 1)) else { return nil }
        return .month(containing: date, calendar: calendar)
    }

    /// The `count` days ending at the end of the day containing `date`.
    public static func lastDays(_ count: Int, endingOn date: Date, calendar: Calendar) -> DateRange {
        let endOfDay = calendar.dateInterval(of: .day, for: date)?.end ?? date
        let start = calendar.date(byAdding: .day, value: -count, to: endOfDay) ?? endOfDay
        return DateRange(start: start, end: endOfDay)
    }

    /// The same-length month immediately before this one (assumes `self` is a month).
    public func previousMonth(calendar: Calendar) -> DateRange {
        let earlier = calendar.date(byAdding: .month, value: -1, to: start) ?? start
        return .month(containing: earlier, calendar: calendar)
    }

    /// Consecutive months overlapping the range, oldest first.
    public func months(calendar: Calendar) -> [DateRange] {
        var result: [DateRange] = []
        var cursor = DateRange.month(containing: start, calendar: calendar)
        while cursor.start < end {
            result.append(cursor)
            cursor = DateRange.month(containing: cursor.end, calendar: calendar)
        }
        return result
    }

    /// Short human label such as "September 2026" or "1 Sep – 15 Oct 2026".
    public func label(calendar: Calendar, locale: Locale = .autoupdatingCurrent) -> String {
        let month = DateRange.month(containing: start, calendar: calendar)
        var style = Date.FormatStyle(date: .omitted, time: .omitted, locale: locale, calendar: calendar, timeZone: calendar.timeZone)
        if month == self {
            style = style.month(.wide).year()
            return start.formatted(style)
        }
        let year = DateRange.year(containing: start, calendar: calendar)
        if year == self {
            return start.formatted(style.year())
        }
        let lastDay = end.addingTimeInterval(-1)
        let dayStyle = style.day().month(.abbreviated)
        return "\(start.formatted(dayStyle)) – \(lastDay.formatted(dayStyle.year()))"
    }
}
