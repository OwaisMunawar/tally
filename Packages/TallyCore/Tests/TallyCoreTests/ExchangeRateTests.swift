import Foundation
import Testing
@testable import TallyCore

@Suite("Exchange rates")
struct ExchangeRateTests {
    @Test("Converts into the base currency")
    func toBase() throws {
        let rates = try Fixture.rates()
        #expect(try rates.toBase(Fixture.eur(10_00)) == Fixture.usd(11_00))
    }

    @Test("Cross conversion goes through the base with a single rounding")
    func crossConversion() throws {
        let rates = try Fixture.rates()
        // 10.00 EUR = 11.00 USD = 8.80 GBP exactly.
        #expect(try rates.convert(Fixture.eur(10_00), to: .gbp) == Money(minorUnits: 8_80, currency: .gbp))
        // 0.01 EUR = 0.011 USD = 0.0088 GBP, which rounds once to 0.01 rather than 0.01 -> 0.01 -> 0.01 drift.
        #expect(try rates.convert(Fixture.eur(1), to: .gbp).minorUnits == 1)
    }

    @Test("Same currency is returned untouched")
    func identity() throws {
        let money = Fixture.eur(12_34)
        #expect(try Fixture.rates().convert(money, to: .eur) == money)
    }

    @Test("Missing rates are a typed error naming the currency")
    func missingRate() throws {
        let rates = try Fixture.rates()
        #expect(throws: FXError.missingRate(.jpy)) {
            try rates.toBase(Money(minorUnits: 500, currency: .jpy))
        }
    }

    @Test("Zero and negative rates are rejected", arguments: ["0", "-1.2"])
    func invalidRates(rate: String) {
        var rates = ExchangeRateTable.baseOnly(.usd)
        #expect(throws: FXError.invalidRate(.eur)) {
            try rates.setRate(Fixture.decimal(rate), for: .eur)
        }
    }

    @Test("A round trip lands within one minor unit", arguments: [Int64(1), 99, 12_345, 9_999_999])
    func roundTrip(minorUnits: Int64) throws {
        let rates = try Fixture.rates()
        let back = try rates.convert(rates.toBase(Fixture.eur(minorUnits)), to: .eur)
        #expect(abs(back.minorUnits - minorUnits) <= 1)
    }
}
