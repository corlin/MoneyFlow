import SwiftUI
import Charts

struct CashFlowChart: View {
    let items: [MonthlyCashFlowItem]
    let assumptions: ProjectionAssumptions

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var selectedItem: MonthlyCashFlowItem?
    @State private var showsAssumptions = false

    private var displayedItem: MonthlyCashFlowItem? {
        selectedItem ?? items.first(where: { $0.endingCash < 0 }) ?? items.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text("12个月现金余量").font(.headline)
                Text("每月完成已记录还款后的预计现金")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let selected = displayedItem {
                selectedMonthCard(selected)
            }

            Chart {
                RuleMark(y: .value("零余额", 0))
                    .foregroundStyle(Color.secondary.opacity(0.55))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))

                ForEach(items) { item in
                    LineMark(
                        x: .value("月份", item.date),
                        y: .value("期末现金", item.endingCash)
                    )
                    .foregroundStyle(Color.appPrimary)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.linear)

                    if item.endingCash < 0 {
                        PointMark(
                            x: .value("月份", item.date),
                            y: .value("现金缺口", item.endingCash)
                        )
                        .foregroundStyle(Color.appWarningDebt)
                        .symbolSize(46)
                    }
                }

                if let selected = displayedItem {
                    RuleMark(x: .value("选中月份", selected.date))
                        .foregroundStyle(Color.appPrimary.opacity(0.45))
                        .lineStyle(StrokeStyle(lineWidth: 1))
                    PointMark(
                        x: .value("选中月份", selected.date),
                        y: .value("选中余额", selected.endingCash)
                    )
                    .foregroundStyle(selected.endingCash < 0 ? Color.appWarningDebt : Color.appPrimary)
                    .symbolSize(60)
                }
            }
            .frame(height: dynamicTypeSize.isAccessibilitySize ? 260 : 210)
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                    if let amount = value.as(Double.self) {
                        AxisValueLabel {
                            Text(amount.formattedCurrencyCompact)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .month, count: 3)) { value in
                    AxisTick()
                    AxisValueLabel(centered: true) {
                        if let date = value.as(Date.self) {
                            Text("\(Calendar.current.component(.month, from: date))月")
                                .font(.caption2)
                        }
                    }
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    Rectangle()
                        .fill(.clear)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    guard let plotFrame = proxy.plotFrame else { return }
                                    let plot = geometry[plotFrame]
                                    let x = value.location.x - plot.origin.x
                                    guard x >= 0, x <= plot.width,
                                          let date: Date = proxy.value(atX: x),
                                          let nearest = items.min(by: {
                                              abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
                                          }) else { return }
                                    if selectedItem?.id != nearest.id {
                                        AppMotion.perform(level: .interactive, reduceMotion: reduceMotion) {
                                            selectedItem = nearest
                                        }
                                    }
                                }
                        )
                }
            }
            .accessibilityElement()
            .accessibilityLabel(CashFlowChartSummary.text(for: items))

            DisclosureGroup("预测假设", isExpanded: $showsAssumptions.animation(AppMotion.animation(for: .spatial, reduceMotion: reduceMotion))) {
                Text(assumptions.disclosureText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color.appCardBackground, in: RoundedRectangle(cornerRadius: 16))
        .sensoryFeedback(.selection, trigger: selectedItem?.id)
        .onAppear {
            if selectedItem == nil { selectedItem = items.first(where: { $0.endingCash < 0 }) ?? items.first }
        }
    }

    private func selectedMonthCard(_ item: MonthlyCashFlowItem) -> some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) { selectedMetrics(item) }
            } else {
                Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 10) {
                    GridRow {
                        metric("\(item.date.yearMonthString)余额", item.endingCash.formattedCurrencyCompact,
                               item.endingCash < 0 ? .appWarningDebt : .primary)
                        metric("预计收入", item.estimatedIncome.formattedCurrencyCompact, .primary)
                    }
                    GridRow {
                        metric("必须支出", item.totalMustPay.formattedCurrencyCompact, .primary)
                        metric("当月净变动", (item.estimatedIncome - item.totalMustPay).formattedCurrencyCompact,
                               item.estimatedIncome - item.totalMustPay < 0 ? .appWarningDebt : .primary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(12)
        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func selectedMetrics(_ item: MonthlyCashFlowItem) -> some View {
        metric("\(item.date.yearMonthString)余额", item.endingCash.formattedCurrencyCompact,
               item.endingCash < 0 ? .appWarningDebt : .primary)
        metric("预计收入", item.estimatedIncome.formattedCurrencyCompact, .primary)
        metric("必须支出", item.totalMustPay.formattedCurrencyCompact, .primary)
        metric("当月净变动", (item.estimatedIncome - item.totalMustPay).formattedCurrencyCompact,
               item.estimatedIncome - item.totalMustPay < 0 ? .appWarningDebt : .primary)
    }

    private func metric(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(color)
                .contentTransition(.numericText())
        }
    }
}
