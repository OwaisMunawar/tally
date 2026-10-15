import Foundation

/// What Tally Plus unlocks.
public enum PlusFeature: String, CaseIterable, Sendable {
    case askTally
    case csvImport
    case unlimitedBudgets

    public var title: String {
        switch self {
        case .askTally: "Ask Tally"
        case .csvImport: "CSV import"
        case .unlimitedBudgets: "Unlimited budgets"
        }
    }
}

public enum AccessTier: String, Sendable, Codable {
    case free, plus
}

/// A purchase as StoreKit reported it, reduced to the fields that decide access.
/// Keeping StoreKit types out of this layer is what makes the rules testable.
public struct PurchaseRecord: Hashable, Sendable {
    public let productID: String
    public let purchaseDate: Date
    public let expirationDate: Date?
    public let revocationDate: Date?
    public let isUpgraded: Bool

    public init(productID: String, purchaseDate: Date, expirationDate: Date?, revocationDate: Date? = nil, isUpgraded: Bool = false) {
        self.productID = productID
        self.purchaseDate = purchaseDate
        self.expirationDate = expirationDate
        self.revocationDate = revocationDate
        self.isUpgraded = isUpgraded
    }
}

public struct EntitlementPolicy: Sendable {
    public let plusProductIDs: Set<String>
    public let freeBudgetLimit: Int

    public init(plusProductIDs: Set<String>, freeBudgetLimit: Int = 3) {
        self.plusProductIDs = plusProductIDs
        self.freeBudgetLimit = freeBudgetLimit
    }

    /// Plus is active if any verified, unrevoked, unexpired Plus purchase exists.
    /// Upgraded transactions are skipped because their replacement carries the access.
    public func tier(for records: [PurchaseRecord], now: Date) -> AccessTier {
        let active = records.contains { record in
            guard plusProductIDs.contains(record.productID), !record.isUpgraded else { return false }
            if let revoked = record.revocationDate, revoked <= now { return false }
            if let expires = record.expirationDate, expires <= now { return false }
            return record.purchaseDate <= now
        }
        return active ? .plus : .free
    }

    public func allows(_ feature: PlusFeature, tier: AccessTier, existingBudgets: Int = 0) -> Bool {
        if tier == .plus { return true }
        switch feature {
        case .unlimitedBudgets: return existingBudgets < freeBudgetLimit
        case .askTally, .csvImport: return false
        }
    }
}
