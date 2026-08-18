import SwiftUI
import Charts

enum SandboxChartMode: String, CaseIterable, Identifiable {
    case balanceLine = "balanceLine"
    case waterfall = "waterfall"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .balanceLine: return "现金余额走势"
        case .waterfall: return "月度收支瀑布"
        }
    }

    var systemImage: String {
        switch self {
        case .balanceLine: return "chart.xyaxis.line"
        case .waterfall: return "chart.bar.xaxis"
        }
    }
}

struct DynamicCashFlowSandboxView: View {
    let result: CashFlowProjectionResult
    @Binding var scenario: PlanningScenario
    var onCommitAsBaseline: () -> Void

    @State private var chartMode: SandboxChartMode = .balanceLine
    @State private var selectedMonthLabel: String? = nil

    private var items: [MonthlyCashFlowItem] { result.baselineItems }
    private var scenarioItems: [MonthlyCashFlowItem] { result.scenarioItems }

    private var selectedItem: MonthlyCashFlowItem? {
        guard let label = selectedMonthLabel else { return items.first }
        return items.first(where: { $0.monthLabel == label }) ?? items.first
    }

    private var selectedScenarioItem: MonthlyCashFlowItem? {
        guard let label = selectedMonthLabel else { return scenarioItems.first }
        return scenarioItems.first(where: { $0.monthLabel == label }) ?? scenarioItems.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 头部：标题、情景重置与形态切换
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("动态推演沙盘")
                            .font(.headline)
                            .foregroundStyle(.primary)

                        if scenario.isModifiedFromBaseline {
                            Text("情景模拟中")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.orange)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.15), in: Capsule())
                        }
                    }
                    Text("点选下方胶囊即刻观察曲线与目标形变")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if scenario.isModifiedFromBaseline {
                    HStack(spacing: 8) {
                        Button("还原") {
                            withAnimation(.spring(duration: 0.25)) {
                                scenario.reset()
                            }
                        }
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)

                        Button("设为基准") {
                            onCommitAsBaseline()
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                    }
                    .padding(.trailing, 4)
                }

                Picker("图表形态", selection: $chartMode) {
                    ForEach(SandboxChartMode.allCases) { mode in
                        Label(mode.title, systemImage: mode.systemImage).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 150)
            }

            // 核心推演图表区域
            VStack(spacing: 8) {
                if chartMode == .balanceLine {
                    lineChartView
                } else {
                    waterfallChartView
                }

                // 连续手势探针明细卡片
                if let item = selectedItem {
                    monthDetailScrubCard(item: item, scenarioItem: selectedScenarioItem)
                }
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))

            // 原生轻量浮动胶囊控制手柄 (Floating Scenario Pills)
            floatingScenarioPills
        }
    }

    // MARK: - 走势折线图 (Line Chart)
    private var lineChartView: some View {
        Chart {
            // 基准轨 (Baseline)
            ForEach(items) { item in
                AreaMark(
                    x: .value("月份", item.monthLabel),
                    y: .value("基准现金", item.endingCash)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.20), Color.blue.opacity(0.01)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                LineMark(
                    x: .value("月份", item.monthLabel),
                    y: .value("基准现金", item.endingCash)
                )
                .foregroundStyle(Color.blue)
                .lineStyle(StrokeStyle(lineWidth: 2.5))

                PointMark(
                    x: .value("月份", item.monthLabel),
                    y: .value("基准现金", item.endingCash)
                )
                .foregroundStyle(item.endingCash < 0 ? Color.red : Color.blue)
                .symbolSize(selectedMonthLabel == item.monthLabel ? 45 : 18)
            }

            // 情景轨 (Scenario) 虚线
            if scenario.isModifiedFromBaseline {
                ForEach(scenarioItems) { scenItem in
                    LineMark(
                        x: .value("月份", scenItem.monthLabel),
                        y: .value("情景现金", scenItem.endingCash)
                    )
                    .foregroundStyle(Color.orange)
                    .lineStyle(StrokeStyle(lineWidth: 2.2, dash: [5, 4]))

                    PointMark(
                        x: .value("月份", scenItem.monthLabel),
                        y: .value("情景现金", scenItem.endingCash)
                    )
                    .foregroundStyle(Color.orange)
                    .symbolSize(selectedMonthLabel == scenItem.monthLabel ? 45 : 18)
                }
            }

            if let selected = selectedItem {
                RuleMark(x: .value("选中月份", selected.monthLabel))
                    .foregroundStyle(Color.secondary.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
            }
        }
        .chartXSelection(value: $selectedMonthLabel)
        .frame(height: 180)
    }

    // MARK: - 瀑布收支柱状图 (Waterfall Chart)
    private var waterfallChartView: some View {
        Chart {
            ForEach(items) { item in
                BarMark(
                    x: .value("月份", item.monthLabel),
                    y: .value("金额", item.estimatedIncome)
                )
                .foregroundStyle(Color.green.opacity(0.85))
                .position(by: .value("类型", "收入"))

                BarMark(
                    x: .value("月份", item.monthLabel),
                    y: .value("金额", item.totalMustPay)
                )
                .foregroundStyle(Color.red.opacity(0.80))
                .position(by: .value("类型", "刚性支出"))

                BarMark(
                    x: .value("月份", item.monthLabel),
                    y: .value("金额", item.monthlySurplus)
                )
                .foregroundStyle(Color.purple.opacity(0.85))
                .position(by: .value("类型", "结余"))
            }

            if let selected = selectedItem {
                RuleMark(x: .value("选中月份", selected.monthLabel))
                    .foregroundStyle(Color.secondary.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
            }
        }
        .chartXSelection(value: $selectedMonthLabel)
        .frame(height: 180)
    }

    // MARK: - 探针明细卡片
    private func monthDetailScrubCard(item: MonthlyCashFlowItem, scenarioItem: MonthlyCashFlowItem?) -> some View {
        VStack(spacing: 6) {
            HStack {
                Text("\(item.monthLabel) 预测明细")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.primary)

                Spacer()

                Text("期末现金: \(item.endingCash.formattedCurrencyCompact)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(item.endingCash < 0 ? .red : .blue)

                if let scen = scenarioItem, scenario.isModifiedFromBaseline {
                    let diff = scen.endingCash - item.endingCash
                    Text("(\(diff >= 0 ? "+" : "")\(diff.formattedCurrencyCompact))")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(diff >= 0 ? .green : .orange)
                }
            }

            HStack(spacing: 10) {
                metricItem(label: "预计收入", value: item.estimatedIncome, color: .green)
                metricItem(label: "刚性支出", value: item.totalMustPay, color: .red)
                metricItem(label: "自由结余", value: item.monthlySurplus, color: .purple)
                metricItem(label: "筑底安全", value: item.endingCash - item.totalMustPay, color: item.endingCash >= item.totalMustPay ? .primary : .orange)
            }
        }
        .padding(10)
        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
    }

    private func metricItem(label: String, value: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value.formattedCurrencyCompact)
                .font(.system(.caption, design: .monospaced, weight: .semibold))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 沉浸式胶囊手柄控制台 (Pill Handlers)
    private var floatingScenarioPills: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 1. 收入冲击胶囊组
            VStack(alignment: .leading, spacing: 6) {
                Text("📉 收入冲击压力测试")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    incomePill(pct: 0.0, title: "基准 (0%)")
                    incomePill(pct: -0.10, title: "-10%")
                    incomePill(pct: -0.20, title: "-20% 承压")
                    incomePill(pct: -0.30, title: "-30% 极值")
                }
            }

            // 2. 还贷策略分流胶囊组
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("⚡ 负债清偿策略")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Spacer()

                    if scenario.repaymentStrategy != .standard && result.strategyInterestSaved > 0 {
                        Text("⚡ 预计省息 \(result.strategyInterestSaved.formattedCurrencyCompact) · 提前 \(result.strategyMonthsSaved) 月")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.orange)
                    }
                }

                HStack(spacing: 8) {
                    ForEach(RepaymentStrategy.allCases) { strat in
                        strategyPill(strat)
                    }
                }
            }

            // 3. 突发单笔支出快捷胶囊
            HStack(spacing: 8) {
                Text("⚠️ 突发开支:")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                lumpPill(amount: 0, title: "无")
                lumpPill(amount: 20000, title: "+¥2万")
                lumpPill(amount: 50000, title: "+¥5万")
                Spacer()
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private func incomePill(pct: Double, title: String) -> some View {
        let isSelected = abs(scenario.incomeAdjustmentPct - pct) < 0.001
        return Button {
            withAnimation(.spring(duration: 0.25)) {
                scenario.incomeAdjustmentPct = pct
            }
        } label: {
            Text(title)
                .font(.caption.weight(isSelected ? .bold : .regular))
                .foregroundStyle(isSelected ? .white : .primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(isSelected ? (pct < 0 ? Color.orange : Color.accentColor) : Color(.tertiarySystemGroupedBackground), in: Capsule())
        }
        .sensoryFeedback(.impact(weight: .light), trigger: scenario.incomeAdjustmentPct)
    }

    private func strategyPill(_ strat: RepaymentStrategy) -> some View {
        let isSelected = scenario.repaymentStrategy == strat
        return Button {
            withAnimation(.spring(duration: 0.25)) {
                scenario.repaymentStrategy = strat
            }
        } label: {
            Text(strat.shortTitle)
                .font(.caption.weight(isSelected ? .bold : .regular))
                .foregroundStyle(isSelected ? .white : .primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color(.tertiarySystemGroupedBackground), in: Capsule())
        }
        .sensoryFeedback(.selection, trigger: scenario.repaymentStrategy)
    }

    private func lumpPill(amount: Double, title: String) -> some View {
        let isSelected = abs(scenario.lumpSumExpense - amount) < 0.01
        return Button {
            withAnimation(.spring(duration: 0.25)) {
                scenario.lumpSumExpense = amount
            }
        } label: {
            Text(title)
                .font(.caption2.weight(isSelected ? .bold : .regular))
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(isSelected ? Color.orange : Color(.tertiarySystemGroupedBackground), in: Capsule())
        }
        .sensoryFeedback(.impact(weight: .light), trigger: scenario.lumpSumExpense)
    }
}
