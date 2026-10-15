import SwiftUI

@main
struct TallyApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var dependencies: AppDependencies
    private let options = LaunchOptions.current

    init() {
        _dependencies = State(initialValue: AppDependencies.live(options: LaunchOptions.current))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(dependencies.ledger)
                .environment(dependencies.plus)
                .environment(dependencies.lock)
                .environment(dependencies.router)
                .environment(dependencies.categorization)
                .environment(dependencies.insights)
                .task { await launch() }
                .onOpenURL { dependencies.router.open($0) }
                .onReceive(NotificationCenter.default.publisher(for: .tallyRouteRequested)) { _ in
                    dependencies.router.handlePendingRoute()
                }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                dependencies.router.handlePendingRoute()
                Task { await dependencies.ledger.reload() }
            case .background:
                dependencies.lock.lock()
            default:
                break
            }
        }
    }

    private func launch() async {
        dependencies.plus.start()
        if options.seedDemoData {
            await dependencies.ledger.seedDemoData()
        } else {
            await dependencies.ledger.load()
        }
        if let tab = options.tab { dependencies.router.tab = tab }
        if let sheet = options.sheet { dependencies.router.sheet = sheet }
        dependencies.router.pendingQuestion = options.question
        dependencies.router.focusedPayee = options.detailPayee
        if options.autoCategorize {
            await dependencies.categorization.categorizePending(in: dependencies.ledger)
        }
    }
}
