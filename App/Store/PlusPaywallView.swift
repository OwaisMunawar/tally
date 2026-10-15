import StoreKit
import SwiftUI
import TallyCore
import TallyUI

/// Tally Plus, sold with StoreKit's own subscription UI.
struct PlusPaywallView: View {
    @Environment(PlusStore.self) private var plus
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        SubscriptionStoreView(productIDs: PlusStore.productIDs) {
            VStack(spacing: TallyTheme.Spacing.large) {
                Image(systemName: "sparkles")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(LinearGradient(colors: [.purple, TallyTheme.accent], startPoint: .topLeading, endPoint: .bottomTrailing))
                Text("Tally Plus").font(.largeTitle.weight(.bold))
                VStack(alignment: .leading, spacing: TallyTheme.Spacing.medium) {
                    ForEach(PlusFeature.allCases, id: \.self) { feature in
                        Label(feature.title + " · " + detail(for: feature), systemImage: icon(for: feature))
                            .font(.subheadline)
                    }
                }
                .padding()
                .glassEffect(.regular, in: .rect(cornerRadius: TallyTheme.Radius.card))
                Text("Still private: Plus features run on your iPhone. There is no Tally server.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
        .subscriptionStoreControlStyle(.prominentPicker)
        .storeButton(.visible, for: .restorePurchases)
        .storeButton(.visible, for: .cancellation)
        .onInAppPurchaseCompletion { _, result in
            if case .success(.success) = result {
                await plus.refresh()
                dismiss()
            }
        }
        .tint(TallyTheme.accent)
    }

    private func detail(for feature: PlusFeature) -> String {
        switch feature {
        case .askTally: "questions answered on device"
        case .csvImport: "bring in any bank export"
        case .unlimitedBudgets: "beyond the free three"
        }
    }

    private func icon(for feature: PlusFeature) -> String {
        switch feature {
        case .askTally: "apple.intelligence"
        case .csvImport: "tablecells"
        case .unlimitedBudgets: "chart.pie"
        }
    }
}
