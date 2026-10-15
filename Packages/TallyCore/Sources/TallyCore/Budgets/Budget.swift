import Foundation

/// A monthly spending limit for one category, in the base currency.
public struct Budget: Identifiable, Hashable, Sendable, Codable {
    public var id: UUID
    public var category: TransactionCategory
    public var monthlyLimit: Money

    public init(id: UUID = UUID(), category: TransactionCategory, monthlyLimit: Money) {
        self.id = id
        self.category = category
        self.monthlyLimit = monthlyLimit
    }
}

public struct BudgetStatus: Identifiable, Hashable, Sendable {
    public enum State: String, Sendable {
        case onTrack, nearLimit, over
    }

    public let budget: Budget
    public let spent: Money
    public let remaining: Money
    /// Spent over limit as a plain ratio for drawing rings; never used for money maths.
    public let progress: Double
    public let state: State

    public var id: UUID { budget.id }

    /// The share of the limit at which a budget turns amber.
    public static let warningThreshold: Decimal = 0.8

    public init(budget: Budget, spent: Money) {
        self.budget = budget
        self.spent = spent
        let limit = budget.monthlyLimit
        self.remaining = (try? limit.subtracting(spent)) ?? .zero(limit.currency)
        if limit.minorUnits <= 0 {
            progress = spent.isPositive ? 1 : 0
            state = spent.isPositive ? .over : .onTrack
            return
        }
        let ratio = Decimal(spent.minorUnits) / Decimal(limit.minorUnits)
        progress = NSDecimalNumber(decimal: ratio).doubleValue
        if spent.minorUnits > limit.minorUnits {
            state = .over
        } else if ratio >= Self.warningThreshold {
            state = .nearLimit
        } else {
            state = .onTrack
        }
    }
}
