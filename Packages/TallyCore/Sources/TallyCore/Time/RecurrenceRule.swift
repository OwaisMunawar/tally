import Foundation

/// How often a recurring transaction repeats.
public struct RecurrenceRule: Hashable, Sendable, Codable {
    public enum Frequency: String, CaseIterable, Sendable, Codable {
        case daily, weekly, monthly, yearly

        var component: Calendar.Component {
            switch self {
            case .daily: .day
            case .weekly: .weekOfYear
            case .monthly: .month
            case .yearly: .year
            }
        }
    }

    public var frequency: Frequency
    public var interval: Int

    public init(frequency: Frequency, interval: Int = 1) {
        self.frequency = frequency
        self.interval = max(1, interval)
    }

    public static let monthly = RecurrenceRule(frequency: .monthly)
    public static let weekly = RecurrenceRule(frequency: .weekly)

    /// Occurrences of the rule anchored at `anchor` that fall inside `range`.
    ///
    /// Each occurrence is computed as `anchor + n * interval` with calendar
    /// arithmetic rather than by stepping from the previous occurrence. Stepping
    /// would let a 31 January anchor decay to the 28th forever after February;
    /// anchoring keeps it on the 31st (or the last day of shorter months). Calendar
    /// arithmetic also keeps wall-clock time stable across daylight-saving changes.
    public func occurrences(anchoredAt anchor: Date, in range: DateRange, until end: Date? = nil, calendar: Calendar) -> [Date] {
        let limit = min(range.end, end ?? .distantFuture)
        var result: [Date] = []
        var step = firstStep(anchor: anchor, notBefore: range.start, calendar: calendar)
        while step < Self.maximumSteps {
            guard let date = calendar.date(byAdding: frequency.component, value: step * interval, to: anchor) else { break }
            if date >= limit { break }
            if date >= range.start && date >= anchor { result.append(date) }
            step += 1
        }
        return result
    }

    /// Skips whole periods that end before `notBefore`, so a daily rule anchored
    /// years ago does not iterate through every past day.
    private func firstStep(anchor: Date, notBefore: Date, calendar: Calendar) -> Int {
        guard notBefore > anchor else { return 0 }
        let elapsed = calendar.dateComponents([frequency.component], from: anchor, to: notBefore)
        let units = elapsed.value(for: frequency.component) ?? 0
        return max(0, units / interval - 1)
    }

    private static let maximumSteps = 100_000
}
