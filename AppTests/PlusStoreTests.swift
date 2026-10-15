import Foundation
import StoreKit
import StoreKitTest
import Testing
import TallyCore
@testable import Tally

/// Real StoreKit 2 purchases against the local `Tally.storekit` configuration.
/// These run inside the app process, so `Transaction.currentEntitlements` sees
/// exactly what a user's device would.
///
/// The simulator's storekitd only accepts a test session for apps Xcode itself
/// installed for development, so these are opt-in: run the Tally scheme's tests
/// from Xcode with `STOREKIT_TESTING=1` in the test environment. Command-line
/// and CI runs skip them; `EntitlementPolicy` tests in TallyCore cover the rules.
@Suite(
    "Tally Plus purchases",
    .serialized,
    .enabled(if: ProcessInfo.processInfo.environment["STOREKIT_TESTING"] == "1", "Needs an Xcode-installed development build")
)
@MainActor
struct PlusStoreTests {
    let session: SKTestSession

    init() throws {
        session = try SKTestSession(configurationFileNamed: "Tally")
        session.resetToDefaultState()
        session.disableDialogs = true
        session.clearTransactions()
    }

    @Test("Buying the yearly plan unlocks Plus through currentEntitlements")
    func purchaseUnlocksPlus() async throws {
        let store = PlusStore()
        await store.refresh()
        #expect(store.tier == .free)
        #expect(!store.allows(.askTally))

        let transaction = try await session.buyProduct(identifier: "com.owaismunawar.tally.plus.yearly")
        #expect(transaction.productID == "com.owaismunawar.tally.plus.yearly")

        await store.refresh()
        #expect(store.tier == .plus)
        #expect(store.allows(.askTally))
        #expect(store.allows(.unlimitedBudgets, existingBudgets: 12))
    }

    @Test("An expired subscription falls back to free")
    func expiryRevokesPlus() async throws {
        let store = PlusStore()
        _ = try await session.buyProduct(identifier: "com.owaismunawar.tally.plus.monthly")
        await store.refresh()
        #expect(store.tier == .plus)

        try session.expireSubscription(productIdentifier: "com.owaismunawar.tally.plus.monthly")
        await store.refresh()
        #expect(store.tier == .free)
    }

    @Test("A refund revokes access")
    func refundRevokesPlus() async throws {
        let store = PlusStore()
        let transaction = try await session.buyProduct(identifier: "com.owaismunawar.tally.plus.monthly")
        await store.refresh()
        #expect(store.tier == .plus)

        try session.refundTransaction(identifier: UInt(transaction.id))
        await store.refresh()
        #expect(store.tier == .free)
    }
}
