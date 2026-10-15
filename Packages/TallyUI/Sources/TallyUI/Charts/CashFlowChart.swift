import Charts
import SwiftUI
import TallyCore

/// Monthly money in versus money out, with net as a line.
public struct CashFlowChart: View {
    private let points: [CashFlowPoint]
    @State private var selectedMonth: Date?

    public init(points: [CashFlowPoint]) {
        self.points = points
    }

    public var body: some View {
        Chart {
            ForEach(points) { point in
                BarMark(x: .value("Month", point.periodStart, unit: .month), y: .value("Amount", point.inflow.chartValue), width: .ratio(0.38))
                    .foregroundStyle(by: .value("Flow", "In"))
                    .position(by: .value("Flow", "In"))
                    .cornerRadius(5)
                BarMark(x: .value("Month", point.periodStart, unit: .month), y: .value("Amount", point.outflow.chartValue), width: .ratio(0.38))
                    .foregroundStyle(by: .value("Flow", "Out"))
                    .position(by: .value("Flow", "Out"))
                    .cornerRadius(5)
            }
            if let selected = selectedPoint {
                RuleMark(x: .value("Month", selected.periodStart, unit: .month))
                    .foregroundStyle(.secondary.opacity(0.25))
                    .lineStyle(StrokeStyle(lineWidth: 36))
                    .annotation(position: .top, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(selected.periodStart, format: .dateTime.month(.wide)).font(.caption2).foregroundStyle(.secondary)
                            Text("Net \(selected.net.formattedWhole())").font(.caption.weight(.semibold)).monospacedDigit()
                        }
                        .padding(8)
                        .glassEffect(.regular, in: .rect(cornerRadius: 10))
                    }
            }
        }
        .chartForegroundStyleScale(["In": TallyTheme.positive, "Out": TallyTheme.negative.opacity(0.85)])
        .chartXSelection(value: $selectedMonth)
        .chartXAxis {
            AxisMarks(values: .stride(by: .month)) { _ in
                AxisValueLabel(format: .dateTime.month(.abbreviated), centered: true)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let amount = value.as(Double.self) { Text(amount, format: .number.notation(.compactName)) }
                }
            }
        }
        .accessibilityLabel("Money in and out per month")
    }

    private var selectedPoint: CashFlowPoint? {
        guard let selectedMonth else { return nil }
        let calendar = Calendar.current
        return points.first { calendar.isDate($0.periodStart, equalTo: selectedMonth, toGranularity: .month) }
    }
}
