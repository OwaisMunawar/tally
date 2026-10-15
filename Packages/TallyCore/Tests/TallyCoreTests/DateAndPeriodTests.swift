import Foundation
import Testing
@testable import TallyCore

@Suite("Date ranges and periods")
struct DateAndPeriodTests {
    let calendar = Fixture.calendar()

    @Test("Months are half-open so midnight on the 1st belongs to one month only")
    func halfOpenMonths() throws {
        let september = try #require(DateRange.month(year: 2026, month: 9, calendar: calendar))
        let midnightOctFirst = Fixture.date(2026, 10, 1, 0)
        #expect(!september.contains(midnightOctFirst))
        #expect(september.next(calendar: calendar).contains(midnightOctFirst))
        #expect(september.contains(Fixture.date(2026, 9, 30, 23, 59)))
    }

    @Test("Parses ISO months, years and keywords")
    func parsesTokens() throws {
        let parser = PeriodParser(calendar: calendar, now: Fixture.date(2026, 10, 15))
        #expect(parser.parse("2026-09")?.label == "September 2026")
        #expect(parser.parse("this_month")?.range == DateRange.month(year: 2026, month: 10, calendar: calendar))
        #expect(parser.parse("2025")?.range == DateRange.year(containing: Fixture.date(2025, 6, 1), calendar: calendar))
        #expect(parser.parse("Last Month")?.label == "September 2026")
    }

    @Test("Last month wraps across the year boundary")
    func lastMonthInJanuary() {
        let parser = PeriodParser(calendar: calendar, now: Fixture.date(2026, 1, 10))
        #expect(parser.parse("last_month")?.range == DateRange.month(year: 2025, month: 12, calendar: calendar))
    }

    @Test("A bare month name means its most recent occurrence, never the future")
    func bareMonthNames() {
        let parser = PeriodParser(calendar: calendar, now: Fixture.date(2026, 10, 15))
        #expect(parser.parse("september")?.range == DateRange.month(year: 2026, month: 9, calendar: calendar))
        #expect(parser.parse("Nov")?.range == DateRange.month(year: 2025, month: 11, calendar: calendar))
        #expect(parser.parse("august 2024")?.range == DateRange.month(year: 2024, month: 8, calendar: calendar))
    }

    @Test("Rejects text that is not a period", arguments: ["", "soon", "2026-13", "banana bread"])
    func rejectsGarbage(text: String) {
        #expect(PeriodParser(calendar: calendar, now: Fixture.date(2026, 10, 15)).parse(text) == nil)
    }

    @Test("Splits a range into the months it overlaps")
    func monthsInRange() {
        let range = DateRange(start: Fixture.date(2026, 5, 20), end: Fixture.date(2026, 8, 3))
        let months = range.months(calendar: calendar)
        #expect(months.count == 4)
        #expect(months.first == DateRange.month(year: 2026, month: 5, calendar: calendar))
    }
}

extension DateRange {
    func next(calendar: Calendar) -> DateRange {
        .month(containing: end, calendar: calendar)
    }
}
