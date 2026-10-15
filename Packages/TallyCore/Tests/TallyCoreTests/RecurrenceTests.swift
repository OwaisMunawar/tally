import Foundation
import Testing
@testable import TallyCore

@Suite("Recurrence")
struct RecurrenceTests {
    let calendar = Fixture.calendar()

    @Test("Monthly on the 31st clamps to short months and returns to the 31st")
    func monthEndAnchoring() {
        let anchor = Fixture.date(2026, 1, 31, 9)
        let range = DateRange(start: anchor, end: Fixture.date(2026, 5, 1))
        let days = RecurrenceRule.monthly
            .occurrences(anchoredAt: anchor, in: range, calendar: calendar)
            .map { calendar.component(.day, from: $0) }
        #expect(days == [31, 28, 31, 30])
    }

    @Test("Daily occurrences keep 09:00 wall-clock time across the March DST change")
    func daylightSavingStart() {
        let anchor = Fixture.date(2026, 3, 6, 9)
        let range = DateRange(start: anchor, end: Fixture.date(2026, 3, 11, 0))
        let dates = RecurrenceRule(frequency: .daily).occurrences(anchoredAt: anchor, in: range, calendar: calendar)
        #expect(dates.count == 5)
        #expect(dates.allSatisfy { calendar.component(.hour, from: $0) == 9 })
        // The night of 7–8 March is only 23 hours long in New York.
        #expect(dates[2].timeIntervalSince(dates[1]) == 23 * 3600)
    }

    @Test("Daily occurrences keep wall-clock time across the November DST change")
    func daylightSavingEnd() {
        let anchor = Fixture.date(2026, 10, 31, 9)
        let range = DateRange(start: anchor, end: Fixture.date(2026, 11, 3, 0))
        let dates = RecurrenceRule(frequency: .daily).occurrences(anchoredAt: anchor, in: range, calendar: calendar)
        #expect(dates.map { calendar.component(.hour, from: $0) } == [9, 9, 9])
        // Clocks go back at 02:00 on 1 November, so that day is 25 hours long.
        #expect(dates[1].timeIntervalSince(dates[0]) == 25 * 3600)
    }

    @Test("The same instant recurs on different local days in different time zones")
    func timeZoneAware() {
        let tokyo = Fixture.calendar(TimeZone(identifier: "Asia/Tokyo") ?? .gmt)
        let anchor = Fixture.date(2026, 1, 31, 20)
        let range = DateRange(start: anchor, end: Fixture.date(2026, 3, 15))
        let newYorkDays = RecurrenceRule.monthly.occurrences(anchoredAt: anchor, in: range, calendar: calendar)
            .map { calendar.component(.day, from: $0) }
        let tokyoDays = RecurrenceRule.monthly.occurrences(anchoredAt: anchor, in: range, calendar: tokyo)
            .map { tokyo.component(.day, from: $0) }
        #expect(newYorkDays == [31, 28])
        // 20:00 on 31 January in New York is already 1 February in Tokyo.
        #expect(tokyoDays == [1, 1])
    }

    @Test("Yearly on 29 February falls back to the 28th in common years")
    func leapDay() {
        let anchor = Fixture.date(2028, 2, 29, 9)
        let range = DateRange(start: anchor, end: Fixture.date(2032, 3, 1))
        let dates = RecurrenceRule(frequency: .yearly).occurrences(anchoredAt: anchor, in: range, calendar: calendar)
        #expect(dates.map { calendar.component(.day, from: $0) } == [29, 28, 28, 28, 29])
    }

    @Test("Fortnightly rules honour interval, range start and end date")
    func intervalAndBounds() {
        let anchor = Fixture.date(2026, 1, 5, 9)
        let rule = RecurrenceRule(frequency: .weekly, interval: 2)
        let range = DateRange(start: Fixture.date(2026, 2, 1), end: Fixture.date(2026, 12, 31))
        let dates = rule.occurrences(anchoredAt: anchor, in: range, until: Fixture.date(2026, 3, 20), calendar: calendar)
        #expect(dates.map { calendar.component(.day, from: $0) } == [2, 16, 2, 16])
    }

    @Test("Materialising recurring transactions is idempotent")
    func idempotentMaterialisation() {
        let template = RecurringTransaction(
            accountID: Fixture.account.id, payee: "Rent", amount: Fixture.usd(-2_000_00),
            category: .housing, rule: .monthly, startDate: Fixture.date(2026, 1, 1, 9)
        )
        let range = DateRange(start: Fixture.date(2026, 1, 1, 0), end: Fixture.date(2026, 4, 15))
        let first = template.dueTransactions(in: range, existing: [], calendar: calendar)
        let second = template.dueTransactions(in: range, existing: first, calendar: calendar)
        #expect(first.count == 4)
        #expect(second.isEmpty)
        #expect(first.allSatisfy { $0.recurringID == template.id })
    }
}
