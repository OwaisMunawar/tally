import Foundation
import Observation
import OSLog
import StoreKit
import TallyCore

/// Tally Plus entitlements from StoreKit 2.
///
/// Access is derived from `Transaction.currentEntitlements` every time rather
/// than cached in a flag, so refunds, expiries and Family Sharing changes take
/// effect on the next refresh. The rules themselves live in `EntitlementPolicy`
/// in TallyCore, where they are unit tested without StoreKit.
@MainActor
@Observable
final class PlusStore {
    static let productIDs = ["com.owaismunawar.tally.plus.yearly", "com.owaismunawar.tally.plus.monthly"]

    private(set) var tier: AccessTier = .free
    let policy = EntitlementPolicy(plusProductIDs: Set(PlusStore.productIDs))

    @ObservationIgnored private let forcePlus: Bool
    @ObservationIgnored private var updates: Task<Void, Never>?

    init(forcePlus: Bool = false) {
        self.forcePlus = forcePlus
        if forcePlus { tier = .plus }
    }

    var isPlus: Bool { tier == .plus }

    func allows(_ feature: PlusFeature, existingBudgets: Int = 0) -> Bool {
        policy.allows(feature, tier: tier, existingBudgets: existingBudgets)
    }

    func start() {
        guard updates == nil else { return }
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result { await transaction.finish() }
                await self?.refresh()
            }
        }
        Task { await refresh() }
    }

    func refresh() async {
        guard !forcePlus else { return }
        tier = policy.tier(for: await Self.currentRecords(), now: .now)
    }

    /// Verified entitlements only; a transaction that fails JWS verification grants nothing.
    nonisolated static func currentRecords() async -> [PurchaseRecord] {
        var records: [PurchaseRecord] = []
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else {
                Logger.store.error("Ignoring an unverified transaction")
                continue
            }
            records.append(PurchaseRecord(
                productID: transaction.productID,
                purchaseDate: transaction.purchaseDate,
                expirationDate: transaction.expirationDate,
                revocationDate: transaction.revocationDate,
                isUpgraded: transaction.isUpgraded
            ))
        }
        return records
    }
}
