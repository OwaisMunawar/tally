import SwiftUI
import TallyCore
import TallyIntelligence
import TallyUI

struct HomeView: View {
    @Environment(LedgerStore.self) private var ledger
    @Environment(AppRouter.self) private var router
    @Environment(InsightService.self) private var insights

    var body: some View {
        NavigationStack {
            ScrollView {
                if let engine = ledger.engine {
                    VStack(alignment: .leading, spacing: TallyTheme.Spacing.xLarge) {
                        NetWorthHeader(engine: engine)
                        AccountCardStack(engine: engine)
                        MonthSummaryCard(engine: engine)
                        if !ledger.pendingReview.isEmpty {
                            ReviewCard()
                        }
                        InsightCard(insight: insights.insight, isGenerating: insights.isGenerating)
                        BudgetPreview(statuses: Array(engine.budgetStatuses().prefix(3)))
                        RecentTransactions(transactions: engine.find(TransactionSearch(limit: 5)))
                    }
                    .padding(.horizontal)
                    .padding(.bottom, TallyTheme.Spacing.xLarge)
                } else if ledger.isLoaded {
                    ContentUnavailableView("Couldn't load your ledger", systemImage: "exclamationmark.triangle",
                                           description: Text(ledger.errorMessage ?? ""))
                } else {
                    ProgressView().padding(.top, 120)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Tally")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Settings", systemImage: "gearshape") { router.sheet = .settings }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add Expense", systemImage: "plus") { router.sheet = .quickAdd }
                        .buttonStyle(.glassProminent)
                }
            }
            .task(id: ledger.data.transactions.count) {
                if let engine = ledger.engine { await insights.refresh(using: engine) }
            }
        }
    }
}

private struct NetWorthHeader: View {
    let engine: LedgerQueryEngine

    var body: some View {
        VStack(alignment: .leading, spacing: TallyTheme.Spacing.xSmall) {
            Text("Net worth").font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
            MoneyText(engine.netWorth, style: .hero)
            Text("Across \(engine.data.accounts.count) accounts in \(engine.baseCurrency.rawValue)")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Account cards in a paging carousel; the foil sheen tracks scroll position.
private struct AccountCardStack: View {
    let engine: LedgerQueryEngine

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: TallyTheme.Spacing.medium) {
                ForEach(engine.data.accounts) { account in
                    let balance = engine.balance(of: account)
                    AccountCardView(account: account, balance: balance, baseEquivalent: try? engine.data.rates.toBase(balance))
                        .containerRelativeFrame(.horizontal) { width, _ in width * 0.86 }
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
    }
}

private struct MonthSummaryCard: View {
    let engine: LedgerQueryEngine

    var body: some View {
        let month = engine.currentMonth
        let comparison = engine.compare(month, with: month.previousMonth(calendar: engine.calendar))
        let flow = engine.monthlyCashFlow(in: month).first
        GlassCard {
            VStack(alignment: .leading, spacing: TallyTheme.Spacing.medium) {
                SectionHeader(month.label(calendar: engine.calendar), systemImage: "calendar")
                HStack(alignment: .top) {
                    StatTile(
                        title: "Spent",
                        value: comparison.first.total.formatted(),
                        caption: changeCaption(comparison),
                        systemImage: "arrow.up.right"
                    )
                    StatTile(title: "Money in", value: (flow?.inflow ?? .zero(engine.baseCurrency)).formatted(),
                             caption: "Net \((flow?.net ?? .zero(engine.baseCurrency)).formatted())", systemImage: "arrow.down.left")
                }
            }
        }
    }

    private func changeCaption(_ comparison: RangeComparison) -> String {
        guard let change = comparison.percentChange else { return "No spending last month" }
        let sign = change >= 0 ? "+" : "−"
        return "\(sign)\(NSDecimalNumber(decimal: change.magnitude).stringValue)% vs last month"
    }
}

private struct ReviewCard: View {
    @Environment(LedgerStore.self) private var ledger
    @Environment(CategorizationService.self) private var categorization

    var body: some View {
        GlassCard(tint: .purple) {
            VStack(alignment: .leading, spacing: TallyTheme.Spacing.medium) {
                Label("\(ledger.pendingReview.count) new transactions to categorise", systemImage: "tray.full.fill")
                    .font(.headline)
                Text(categorization.availability.isAvailable
                     ? "Apple Intelligence will suggest categories on this iPhone. Nothing leaves the device."
                     : categorization.availability.explanation)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button {
                    Task { await categorization.categorizePending(in: ledger) }
                } label: {
                    if categorization.isRunning {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Label("Categorise now", systemImage: "apple.intelligence").frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.glassProminent)
                .disabled(categorization.isRunning)
            }
        }
    }
}

private struct InsightCard: View {
    let insight: MonthlyInsight?
    let isGenerating: Bool

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: TallyTheme.Spacing.small) {
                HStack {
                    Label("Monthly insight", systemImage: "sparkles").font(.subheadline.weight(.semibold)).foregroundStyle(.purple)
                    Spacer()
                    if let insight {
                        Text(insight.source == .onDeviceModel ? "On-device AI" : "Summary")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                if let insight {
                    Text(insight.headline).font(.title3.weight(.semibold))
                    Text(insight.body).font(.body).foregroundStyle(.secondary)
                } else {
                    Text(isGenerating ? "Writing your summary…" : "Your summary appears once there's spending this month.")
                        .foregroundStyle(.secondary)
                        .redacted(reason: isGenerating ? .placeholder : [])
                }
            }
        }
    }
}

private struct BudgetPreview: View {
    let statuses: [BudgetStatus]
    @Environment(AppRouter.self) private var router

    var body: some View {
        if !statuses.isEmpty {
            VStack(alignment: .leading, spacing: TallyTheme.Spacing.medium) {
                HStack {
                    SectionHeader("Budgets", systemImage: "chart.pie")
                    Button("See all") { router.tab = .budgets }.font(.subheadline)
                }
                GlassEffectContainer(spacing: TallyTheme.Spacing.medium) {
                    HStack(spacing: TallyTheme.Spacing.medium) {
                        ForEach(statuses) { status in
                            VStack(spacing: TallyTheme.Spacing.small) {
                                ProgressRing(progress: status.progress, tint: TallyTheme.color(for: status.state), lineWidth: 7) {
                                    Image(systemName: status.budget.category.systemImage)
                                        .foregroundStyle(TallyTheme.color(for: status.budget.category))
                                }
                                .frame(width: 54, height: 54)
                                Text(status.budget.category.displayName).font(.caption.weight(.semibold)).lineLimit(1)
                                Text(status.remaining.isNegative ? "\(status.remaining.magnitude.formattedWhole()) over"
                                                                  : "\(status.remaining.formattedWhole()) left")
                                    .font(.caption2)
                                    .foregroundStyle(status.state == .over ? TallyTheme.negative : .secondary)
                                    .monospacedDigit()
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, TallyTheme.Spacing.medium)
                            .glassEffect(.regular, in: .rect(cornerRadius: 20))
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
            }
        }
    }
}

private struct RecentTransactions: View {
    let transactions: [LedgerTransaction]
    @Environment(AppRouter.self) private var router

    var body: some View {
        VStack(alignment: .leading, spacing: TallyTheme.Spacing.medium) {
            HStack {
                SectionHeader("Recent", systemImage: "clock")
                Button("Activity") { router.tab = .activity }.font(.subheadline)
            }
            GlassCard {
                VStack(spacing: TallyTheme.Spacing.medium) {
                    ForEach(transactions) { transaction in
                        TransactionRow(transaction: transaction)
                        if transaction.id != transactions.last?.id { Divider() }
                    }
                }
            }
        }
    }
}
