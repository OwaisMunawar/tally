import Foundation
import Testing
@testable import TallyCore

@Suite("Money")
struct MoneyTests {
    @Test("Rounds half to even by default", arguments: [
        ("2.345", Int64(234)), ("2.355", 236), ("-2.345", -234), ("0.005", 0), ("0.015", 2),
    ])
    func bankersRounding(input: String, expected: Int64) throws {
        let money = try Money(Fixture.decimal(input), currency: .usd)
        #expect(money.minorUnits == expected)
    }

    @Test("Half away from zero rounds both signs outward")
    func halfAwayFromZero() throws {
        #expect(try Money(Fixture.decimal("2.345"), currency: .usd, rounding: .halfAwayFromZero).minorUnits == 235)
        #expect(try Money(Fixture.decimal("-2.345"), currency: .usd, rounding: .halfAwayFromZero).minorUnits == -235)
    }

    @Test("Toward zero truncates negatives up, not down")
    func towardZero() throws {
        #expect(try Money(Fixture.decimal("2.349"), currency: .usd, rounding: .towardZero).minorUnits == 234)
        #expect(try Money(Fixture.decimal("-2.349"), currency: .usd, rounding: .towardZero).minorUnits == -234)
    }

    @Test("Respects ISO 4217 minor units for zero- and three-digit currencies")
    func minorUnitExponents() throws {
        #expect(try Money(Fixture.decimal("1234.5"), currency: .jpy).minorUnits == 1234)
        #expect(try Money(Fixture.decimal("1235.5"), currency: .jpy).minorUnits == 1236)
        #expect(try Money(Fixture.decimal("1.2345"), currency: .kwd).minorUnits == 1234)
        #expect(Money(minorUnits: 1234, currency: .kwd).amount == Fixture.decimal("1.234"))
    }

    @Test("Decimal storage avoids the 0.1 + 0.2 floating point trap")
    func noFloatingPointDrift() throws {
        let sum = try Money(Fixture.decimal("0.1"), currency: .usd).adding(Money(Fixture.decimal("0.2"), currency: .usd))
        #expect(sum == (try Money(Fixture.decimal("0.3"), currency: .usd)))
        #expect(sum.amount == Fixture.decimal("0.3"))
    }

    @Test("Adding different currencies is a typed error")
    func currencyMismatch() {
        #expect(throws: MoneyError.currencyMismatch(.usd, .eur)) {
            try Fixture.usd(100).adding(Fixture.eur(100))
        }
    }

    @Test("Overflow is reported instead of trapping")
    func overflow() {
        #expect(throws: MoneyError.overflow) {
            try Money(minorUnits: .max, currency: .usd).adding(Fixture.usd(1))
        }
        #expect(throws: MoneyError.overflow) {
            try Money(Fixture.decimal("1e30"), currency: .usd)
        }
    }

    @Test("Allocation never loses a cent", arguments: [Int64(10000), 1, -1001, 7])
    func allocationSumsBack(minorUnits: Int64) throws {
        let parts = try Fixture.usd(minorUnits).allocated(into: 3)
        #expect(parts.count == 3)
        #expect(try Money.sum(parts, currency: .usd).minorUnits == minorUnits)
        let spread = parts.map(\.minorUnits)
        #expect((spread.max() ?? 0) - (spread.min() ?? 0) <= 1)
    }

    @Test("Allocating into zero parts is rejected")
    func allocationIntoZero() {
        #expect(throws: MoneyError.invalidAllocation) { try Fixture.usd(100).allocated(into: 0) }
    }

    @Test("Formats with the currency's own precision")
    func formatting() {
        let locale = Locale(identifier: "en_US")
        #expect(Fixture.usd(123_456).formatted(locale: locale) == "$1,234.56")
        #expect(Money(minorUnits: 1500, currency: .jpy).formatted(locale: locale) == "¥1,500")
        #expect(Fixture.usd(-4_50).formatted(locale: locale) == "-$4.50")
    }

    @Test("Codable round trip keeps minor units and currency")
    func codable() throws {
        let original = Money(minorUnits: -98_765, currency: .eur)
        let decoded = try JSONDecoder().decode(Money.self, from: JSONEncoder().encode(original))
        #expect(decoded == original)
    }
}
