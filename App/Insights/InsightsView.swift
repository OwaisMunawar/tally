import SwiftUI
import TallyCore
import TallyUI

struct InsightsView: View {
    @Environment(LedgerStore.self) private var ledger
    @State private var monthOffset = 0
    @State private var selectedCategory: TransactionCategory?

    var body: some View {
        NavigationStack {
            ScrollView {
                if let engine = ledger.engine {
                    let month = month(engine)
                    VStack(spacing: TallyTheme.Spacing.large) {
                        monthPicker(month, engine: engine)
                        trendCard(month, engine: engine)
                        categoryCard(month, engine: engine)
                        cashFlowCard(engine)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, TallyTheme.Spacing.xLarge)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Insights")
        }
    }

    private func month(_ engine: LedgerQueryEngine) -> DateRange {
        let start = engine.calendar.date(byAdding: .month, value: monthOffset, to: engine.currentMonth.start) ?? engine.currentMonth.start
        return .month(containing: start, calendar: engine.calendar)
    }

    private func monthPicker(_ month: DateRange, engine: LedgerQueryEngine) -> some View {
        HStack {
            Button("Previous month", systemImage: "chevron.left") { monthOffset -= 1; selectedCategory = nil }
                .labelStyle(.iconOnly)
                .disabled(monthOffset <= -5)
            Spacer()
            Text(month.label(calendar: engine.calendar)).font(.headline).contentTransition(.numericText())
            Spacer()
            Button("Next month", systemImage: "chevron.right") { monthOffset += 1; selectedCategory = nil }
                .labelStyle(.iconOnly)
                .disabled(monthOffset >= 0)
        }
        .buttonStyle(.glass)
        .animation(.snappy, value: monthOffset)
    }

    private func trendCard(_ month: DateRange, engine: LedgerQueryEngine) -> some View {
        let previous = month.previousMonth(calendar: engine.calendar)
        let total = engine.spending(in: month).total
        return GlassCard {
            VStack(alignment: .leading, spacing: TallyTheme.Spacing.medium) {
                SectionHeader("Spend over time", systemImage: "chart.line.uptrend.xyaxis")
                HStack(alignment: .firstTextBaseline) {
                    MoneyText(total).font(.title2.weight(.bold))
                    Text("vs \(engine.spending(in: previous).total.formattedWhole()) last month (dashed)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                SpendTrendChart(
                    current: .init(id: "current", points: engine.dailySpend(in: month)),
                    previous: .init(id: "previous", points: engine.dailySpend(in: previous))
                )
                .frame(height: 200)
            }
        }
    }

    private func categoryCard(_ month: DateRange, engine: LedgerQueryEngine) -> some View {
        let totals = engine.spendByCategory(in: month)
        return GlassCard {
            VStack(alignment: .leading, spacing: TallyTheme.Spacing.medium) {
                SectionHeader("By category", systemImage: "chart.pie")
                if totals.isEmpty {
                    Text("No spending yet.").foregroundStyle(.secondary)
                } else {
                    CategoryDonutChart(totals: totals, selection: $selectedCategory)
                        .frame(height: 220)
                    ForEach(totals.prefix(6)) { total in
                        Button {
                            selectedCategory = selectedCategory == total.category ? nil : total.category
                        } label: {
                            HStack {
                                Circle().fill(TallyTheme.color(for: total.category)).frame(width: 10, height: 10)
                                Text(total.category.displayName)
                                Spacer()
                                Text("\(total.transactionCount)").foregroundStyle(.secondary).font(.caption)
                                Text(total.total.formatted()).monospacedDigit()
                            }
                            .font(.subheadline.weight(selectedCategory == total.category ? .semibold : .regular))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func cashFlowCard(_ engine: LedgerQueryEngine) -> some View {
        let start = engine.calendar.date(byAdding: .month, value: -5, to: engine.currentMonth.start) ?? engine.currentMonth.start
        let points = engine.monthlyCashFlow(in: DateRange(start: start, end: engine.currentMonth.end))
        return GlassCard {
            VStack(alignment: .leading, spacing: TallyTheme.Spacing.medium) {
                SectionHeader("Cash flow", systemImage: "arrow.left.arrow.right")
                CashFlowChart(points: points).frame(height: 200)
                Text("Transfers between your own accounts are excluded.").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
