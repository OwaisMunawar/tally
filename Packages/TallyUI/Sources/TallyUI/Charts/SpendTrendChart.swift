import Charts
import SwiftUI
import TallyCore

/// Cumulative spend through a month against the previous month, with a
/// draggable selection that reads out the exact running total.
public struct SpendTrendChart: View {
    public struct Series: Identifiable {
        public let id: String
        public let points: [DailySpend]

        public init(id: String, points: [DailySpend]) {
            self.id = id
            self.points = points
        }
    }

    private let current: Series
    private let previous: Series?
    @State private var selectedDay: Int?

    public init(current: Series, previous: Series?) {
        self.current = current
        self.previous = previous
    }

    public var body: some View {
        Chart {
            if let previous {
                ForEach(cumulative(previous)) { point in
                    LineMark(x: .value("Day", point.day), y: .value("Spent", point.value), series: .value("Month", previous.id))
                        .foregroundStyle(.secondary.opacity(0.6))
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 4]))
                }
            }
            ForEach(cumulative(current)) { point in
                AreaMark(x: .value("Day", point.day), y: .value("Spent", point.value))
                    .foregroundStyle(LinearGradient(colors: [TallyTheme.accent.opacity(0.3), .clear], startPoint: .top, endPoint: .bottom))
                LineMark(x: .value("Day", point.day), y: .value("Spent", point.value), series: .value("Month", current.id))
                    .foregroundStyle(TallyTheme.accent)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                    .interpolationMethod(.monotone)
            }
            if let selectedDay, let point = cumulative(current).first(where: { $0.day == selectedDay }) {
                RuleMark(x: .value("Day", selectedDay))
                    .foregroundStyle(.secondary.opacity(0.4))
                    .annotation(position: .top, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Day \(selectedDay)").font(.caption2).foregroundStyle(.secondary)
                            Text(point.money.formatted()).font(.caption.weight(.semibold)).monospacedDigit()
                        }
                        .padding(8)
                        .glassEffect(.regular, in: .rect(cornerRadius: 10))
                    }
                PointMark(x: .value("Day", selectedDay), y: .value("Spent", point.value))
                    .foregroundStyle(TallyTheme.accent)
            }
        }
        .chartXSelection(value: $selectedDay)
        .chartXScale(domain: 1...31)
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let amount = value.as(Double.self) { Text(amount, format: .currency(code: currencyCode).precision(.fractionLength(0))) }
                }
            }
        }
        .accessibilityLabel("Cumulative spending this month compared with last month")
    }

    private var currencyCode: String {
        current.points.first?.total.currency.rawValue ?? "USD"
    }

    private struct Point: Identifiable {
        let day: Int
        let money: Money
        var value: Double { money.chartValue }
        var id: Int { day }
    }

    private func cumulative(_ series: Series) -> [Point] {
        var running: Int64 = 0
        let calendar = Calendar.current
        return series.points.map { point in
            running += point.total.minorUnits
            return Point(day: calendar.component(.day, from: point.day), money: Money(minorUnits: running, currency: point.total.currency))
        }
    }
}
