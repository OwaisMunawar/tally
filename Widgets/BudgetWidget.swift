import AppIntents
import SwiftUI
import TallyCore
import TallyUI
import WidgetKit

struct BudgetEntry: TimelineEntry {
    let date: Date
    let remaining: Money
    let limit: Money
    let statuses: [BudgetStatus]
    let presets: [WidgetPreset]

    var progress: Double {
        guard limit.minorUnits > 0 else { return 0 }
        return 1 - Double(remaining.minorUnits) / Double(limit.minorUnits)
    }

    static let placeholder = BudgetEntry(
        date: .now,
        remaining: Money(minorUnits: 412_30, currency: .usd),
        limit: Money(minorUnits: 1_610_00, currency: .usd),
        statuses: [],
        presets: []
    )
}

struct BudgetTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> BudgetEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (BudgetEntry) -> Void) {
        Task { completion(await entry()) }
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<BudgetEntry>) -> Void) {
        Task {
            let entry = await entry()
            // Budgets roll over at midnight on the 1st; otherwise the app reloads us on every change.
            let midnight = Calendar.autoupdatingCurrent.startOfDay(for: .now.addingTimeInterval(86_400))
            completion(Timeline(entries: [entry], policy: .after(midnight)))
        }
    }

    private func entry() async -> BudgetEntry {
        guard let engine = try? await SharedLedger.engine() else { return .placeholder }
        let totals = engine.totalBudgetRemaining()
        return BudgetEntry(
            date: engine.now,
            remaining: totals.remaining,
            limit: totals.limit,
            statuses: Array(engine.budgetStatuses().prefix(3)),
            presets: WidgetPreset.presets(from: engine)
        )
    }
}

struct BudgetWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetKinds.budget, provider: BudgetTimelineProvider()) { entry in
            BudgetWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    LinearGradient(colors: [Color(.systemBackground), TallyTheme.accent.opacity(0.08)], startPoint: .top, endPoint: .bottom)
                }
        }
        .configurationDisplayName("Budget Left")
        .description("What's left to spend this month, with one-tap repeat purchases.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct BudgetWidgetView: View {
    let entry: BudgetEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemMedium: medium
        default: small
        }
    }

    private var tint: Color {
        entry.remaining.isNegative ? TallyTheme.negative : entry.progress > 0.8 ? TallyTheme.warning : TallyTheme.positive
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                ProgressRing(progress: entry.progress, tint: tint, lineWidth: 6)
                    .frame(width: 34, height: 34)
                Spacer()
                Button(intent: QuickAddIntent()) {
                    Image(systemName: "plus").font(.headline)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.circle)
                .tint(TallyTheme.accent)
                .accessibilityLabel("Add expense")
            }
            Spacer(minLength: 0)
            Text(entry.remaining.formattedWhole())
                .font(.system(.title, design: .rounded, weight: .bold))
                .monospacedDigit()
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .contentTransition(.numericText())
            Text("left of \(entry.limit.formattedWhole())")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var medium: some View {
        HStack(spacing: 14) {
            small.frame(maxWidth: 130)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(entry.statuses) { status in
                    HStack(spacing: 6) {
                        Image(systemName: status.budget.category.systemImage)
                            .foregroundStyle(TallyTheme.color(for: status.budget.category))
                            .frame(width: 16)
                        Text(status.budget.category.displayName).font(.caption).lineLimit(1)
                        Spacer(minLength: 2)
                        Text(status.remaining.isNegative ? "−\(status.remaining.magnitude.formattedWhole())" : status.remaining.formattedWhole())
                            .font(.caption.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(TallyTheme.color(for: status.state))
                    }
                }
                Spacer(minLength: 0)
                HStack(spacing: 6) {
                    ForEach(entry.presets, id: \.self) { preset in
                        Button(intent: LogPresetExpenseIntent(preset: preset)) {
                            VStack(spacing: 0) {
                                Text(preset.payee).font(.caption2).lineLimit(1)
                                Text(preset.amount.formatted()).font(.caption2.weight(.bold)).monospacedDigit()
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(TallyTheme.color(for: preset.category))
                        .accessibilityLabel("Log \(preset.amount.formatted()) at \(preset.payee)")
                    }
                }
            }
        }
    }
}
