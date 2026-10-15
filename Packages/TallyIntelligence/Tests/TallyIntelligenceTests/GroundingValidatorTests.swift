import Testing
@testable import TallyIntelligence

@Suite("Grounding validator")
struct GroundingValidatorTests {
    let validator = GroundingValidator()
    let evidence = """
    Spending on food, September 2026 compared with August 2026:
    - September 2026: $1,137.10 (41 transactions)
    - August 2026: $655.10 (35 transactions)
    - Difference: $482.00 more in September 2026 (73.6% higher)
    """

    @Test("Figures copied from tool output are verified")
    func copiedFigures() {
        let report = validator.validate(
            answer: "You spent $1,137.10 on food in September, $482.00 more than August's $655.10 (73.6% higher).",
            evidence: [evidence]
        )
        #expect(report.isGrounded)
        #expect(report.verified == ["$1,137.10", "$482.00", "$655.10", "73.6%"])
    }

    @Test("Invented or self-computed figures are flagged")
    func inventedFigures() {
        let report = validator.validate(answer: "That's $481.90 more, roughly 74.1% up, across 76 purchases.", evidence: [evidence])
        #expect(report.unverified == ["$481.90", "74.1%", "76"])
    }

    @Test("Coarser rounding of a real figure is allowed, finer precision is not")
    func rounding() {
        #expect(validator.validate(answer: "About $1,137 on food.", evidence: [evidence]).isGrounded)
        #expect(validator.validate(answer: "Up 74%.", evidence: [evidence]).isGrounded)
        #expect(!validator.validate(answer: "Exactly $655.104.", evidence: [evidence]).isGrounded)
    }

    @Test("Years, day-of-month and ordinals are context, not claims")
    func dates() {
        let report = validator.validate(answer: "In September 2026, by September 30 or the 1st of October, you spent $655.10.", evidence: [evidence])
        #expect(report.isGrounded)
        #expect(report.verified == ["$655.10"])
    }

    @Test("A negative figure matches its magnitude in tool output")
    func signs() {
        let report = validator.validate(answer: "The refund was -$655.10.", evidence: [evidence])
        #expect(report.isGrounded)
    }

    @Test("With no tool output, any money figure is unverified")
    func noEvidence() {
        #expect(validator.validate(answer: "You spent $300 on dining.", evidence: []).unverified == ["$300"])
        #expect(validator.validate(answer: "I couldn't find that.", evidence: []).isGrounded)
    }
}
