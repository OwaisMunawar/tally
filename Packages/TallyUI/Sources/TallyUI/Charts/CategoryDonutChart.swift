import Charts
import SwiftUI
import TallyCore

/// Spending share by category. Tapping or dragging around the ring selects a
/// category and the centre reads out its total.
public struct CategoryDonutChart: View {
    private let totals: [CategoryTotal]
    @Binding private var selection: TransactionCategory?
    @State private var selectedValue: Double?

    public init(totals: [CategoryTotal], selection: Binding<TransactionCategory?>) {
        self.totals = totals
        _selection = selection
    }

    public var body: some View {
        Chart(totals) { total in
            SectorMark(
                angle: .value("Spent", total.total.chartValue),
                innerRadius: .ratio(0.62),
                angularInset: 1.5
            )
            .cornerRadius(4)
            .foregroundStyle(TallyTheme.color(for: total.category))
            .opacity(selection == nil || selection == total.category ? 1 : 0.35)
            .accessibilityLabel(total.category.displayName)
            .accessibilityValue(total.total.formatted())
        }
        .chartAngleSelection(value: $selectedValue)
        .chartLegend(.hidden)
        .chartBackground { proxy in
            GeometryReader { geometry in
                if let frame = proxy.plotFrame {
                    let rect = geometry[frame]
                    centerLabel.position(x: rect.midX, y: rect.midY)
                }
            }
        }
        .onChange(of: selectedValue) { _, value in
            guard let value else { return }
            selection = category(at: value)
        }
    }

    @ViewBuilder
    private var centerLabel: some View {
        let focus = totals.first { $0.category == selection }
        let sum = totals.reduce(Int64(0)) { $0 + $1.total.minorUnits }
        VStack(spacing: 2) {
            Text(focus?.category.displayName ?? "Total")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let focus {
                Text(focus.total.formattedWhole()).font(.title3.weight(.bold)).monospacedDigit()
            } else if let currency = totals.first?.total.currency {
                Text(Money(minorUnits: sum, currency: currency).formattedWhole()).font(.title3.weight(.bold)).monospacedDigit()
            }
        }
    }

    /// Angle selection reports a cumulative value; walk the sectors to find its owner.
    private func category(at value: Double) -> TransactionCategory? {
        var running = 0.0
        for total in totals {
            running += total.total.chartValue
            if value <= running { return total.category }
        }
        return totals.last?.category
    }
}
