import Foundation
import Testing
@testable import TallyIntelligence

@Suite("Ask Tally tools")
struct LedgerToolTests {
    func context() throws -> ToolContext {
        ToolContext(engine: try Ledger.engine())
    }

    @Test("spendByCategory lists categories with converted totals")
    func spendByCategory() async throws {
        let output = try await SpendByCategoryTool(context: context()).call(arguments: .init(period: "2026-09", category: "all"))
        #expect(output == """
        Spending by category in September 2026:
        - Groceries: $84.20 (1 transaction)
        - Dining: $55.30 (3 transactions)
        Total: $139.50 (4 transactions)
        """)
    }

    @Test("spendByCategory understands groups like food")
    func foodGroup() async throws {
        let output = try await SpendByCategoryTool(context: context()).call(arguments: .init(period: "september", category: "food"))
        #expect(output == "Spending on food in September 2026: $139.50 across 4 transactions.")
    }

    @Test("compareRanges spells out direction and percent so the model never computes")
    func compare() async throws {
        let output = try await CompareRangesTool(context: context())
            .call(arguments: .init(firstPeriod: "2026-09", secondPeriod: "last_month_of_summer", category: "food"))
        #expect(output.hasPrefix("Unrecognised period 'last_month_of_summer'"))

        let real = try await CompareRangesTool(context: context())
            .call(arguments: .init(firstPeriod: "2026-09", secondPeriod: "2026-08", category: "food"))
        #expect(real.contains("- September 2026: $139.50 (4 transactions)"))
        #expect(real.contains("- August 2026: $67.50 (2 transactions)"))
        #expect(real.contains("- Difference: $72.00 more in September 2026 (106.7% higher)"))
    }

    @Test("topPayees ranks merchants within a category")
    func topPayees() async throws {
        let output = try await TopPayeesTool(context: context()).call(arguments: .init(period: "2026-09", category: "dining", limit: 2))
        #expect(output == """
        Top payees for Dining in September 2026:
        1. Time Out Market: $32.40 (1 transaction)
        2. Sweetgreen: $16.40 (1 transaction)
        """)
    }

    @Test("findTransactions shows the base-currency value of foreign amounts")
    func findTransactions() async throws {
        let output = try await FindTransactionsTool(context: context()).call(arguments: .init(query: "", period: "all", category: "dining", limit: 2))
        #expect(output.contains("Time Out Market: -€30.00 (-$32.40) [Dining]"))
        #expect(output.components(separatedBy: "\n").count == 3)
        let coffee = try await FindTransactionsTool(context: context())
            .call(arguments: .init(query: "blue bottle", period: "2026-08", category: "all", limit: 5))
        #expect(coffee.contains("Aug 12, 2026 Blue Bottle Coffee: -$5.75"))
    }

    @Test("budgetStatus reports what is left and what is over")
    func budgets() async throws {
        let output = try await BudgetStatusTool(context: context()).call(arguments: .init(month: "2026-09"))
        #expect(output.contains("- Dining: spent $55.30 of $60.00, $4.70 left, close to the limit"))
        #expect(output.contains("- Groceries: spent $84.20 of $400.00, $315.80 left, on track"))
    }
}
