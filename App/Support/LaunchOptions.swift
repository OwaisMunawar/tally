import Foundation

/// Launch arguments for demos, UI tests and screenshots, e.g.
/// `-demoData -tab ask -ask "How much did I spend on food in September vs August?"`.
struct LaunchOptions: Sendable {
    var seedDemoData = false
    var tab: AppTab?
    var question: String?
    var sheet: AppSheet?
    var autoCategorize = false
    var detailPayee: String?
    var unlockPlus = false

    static let current = LaunchOptions(arguments: ProcessInfo.processInfo.arguments)

    init(arguments: [String]) {
        func value(after flag: String) -> String? {
            guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else { return nil }
            return arguments[index + 1]
        }
        seedDemoData = arguments.contains("-demoData")
        tab = value(after: "-tab").flatMap(AppTab.init(rawValue:))
        question = value(after: "-ask")
        sheet = value(after: "-sheet").flatMap(AppSheet.init(rawValue:))
        autoCategorize = arguments.contains("-autoCategorize")
        detailPayee = value(after: "-detail")
        #if DEBUG
        // Screenshot runs need Plus screens without a purchase; never honoured in Release.
        unlockPlus = arguments.contains("-unlockPlus")
        #endif
    }
}
