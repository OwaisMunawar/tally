import SwiftUI
import TallyUI

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AppRouter.self) private var router
    @Environment(AppLock.self) private var lock

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.tab) {
            Tab("Home", systemImage: "house.fill", value: AppTab.home) {
                HomeView()
            }
            Tab("Activity", systemImage: "list.bullet.rectangle.portrait.fill", value: AppTab.activity) {
                ActivityView()
            }
            Tab("Insights", systemImage: "chart.xyaxis.line", value: AppTab.insights) {
                InsightsView()
            }
            Tab("Budgets", systemImage: "chart.pie.fill", value: AppTab.budgets) {
                BudgetsView()
            }
            Tab("Ask", systemImage: "apple.intelligence", value: AppTab.ask) {
                AskTallyView()
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .tint(TallyTheme.accent)
        .sheet(item: $router.sheet) { sheet in
            switch sheet {
            case .quickAdd: TransactionEditor(mode: .create)
            case .store: PlusPaywallView()
            case .importCSV: CSVImportView()
            case .settings: SettingsView()
            }
        }
        .overlay {
            if lock.isLocked || scenePhase != .active {
                PrivacyShield().transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.2), value: lock.isLocked)
    }
}

#Preview {
    let dependencies = AppDependencies.preview()
    RootView()
        .environment(dependencies.ledger)
        .environment(dependencies.plus)
        .environment(dependencies.lock)
        .environment(dependencies.router)
        .environment(dependencies.categorization)
        .environment(dependencies.insights)
        .task { await dependencies.ledger.load() }
}
