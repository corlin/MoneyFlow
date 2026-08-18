import SwiftUI
import Charts

public enum SandboxChartMode: String, CaseIterable, Identifiable {
    case balanceLine = "balanceLine"
    case waterfall = "waterfall"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .balanceLine: return "现金余额走势"
        case .waterfall: return "月度收支瀑布"
        }
    }

    public var systemImage: String {
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
    @State private var isControlsExpanded: Bool = true

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
            // 头部：标题与视图切换器
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("动态现金流推演沙盘")
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

                    Text("双轨推演 · 压力测试 · 还贷策略仿真")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Picker("图表形态", selection: $chartMode) {
                    ForEach(SandboxChartMode.allCases) { mode in
                        Label(mode.title, systemImage: mode.systemImage).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 170)
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

            // 策略省息与提速高亮 Banner (若启用了雪崩法或滚雪球)
            if scenario.repaymentStrategy != .standard && result.strategyInterestSaved > 0 {
                strategySavingBanner
            }

            // 可交互推演调节控制台
            sandboxControlsCard
        }
    }

    // MARK: - 走势折线图 (Line Chart)
    private var lineChartView: some View {
        Chart {
            // 基准轨 (Baseline) 面积与折线
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

            // 情景轨 (Scenario) 虚线对比
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

            // 选中的指示竖线
            if let selected = selectedItem {
                RuleMark(x: .value("选中月份", selected.monthLabel))
                    .foregroundStyle(Color.secondary.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
            }
        }
        .chartXSelection(value: $selectedMonthLabel)
        .frame(height: 190)
    }

    // MARK: - 瀑布收支柱状图 (Waterfall Chart)
    private var waterfallChartView: some View {
        Chart {
            ForEach(items) { item in
                // 收入柱
                BarMark(
                    x: .value("月份", item.monthLabel),
                    y: .value("金额", item.estimatedIncome)
                )
                .foregroundStyle(Color.green.opacity(0.85))
                .position(by: .value("类型", "收入"))

                // 刚性流出柱
                BarMark(
                    x: .value("月份", item.monthLabel),
                    y: .value("金额", item.totalMustPay)
                )
                .foregroundStyle(Color.red.opacity(0.80))
                .position(by: .value("类型", "刚性支出"))

                // 净结余柱
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
        .frame(height: 190)
    }

    // MARK: - 探针明细卡片
    private func monthDetailScrubCard(item: MonthlyCashFlowItem, scenarioItem: MonthlyCashFlowItem?) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text("\(item.monthLabel) 预测明细")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.primary)

                Spacer()

                Text("期末现金: \(item.endingCash.formattedCurrency())")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(item.endingCash < 0 ? .red : .blue)

                if let scen = scenarioItem, scenario.isModifiedFromBaseline {
                    let diff = scen.endingCash - item.endingCash
                    Text("(\(diff >= 0 ? "+" : "")\(diff.formattedCurrency(style: .compact)))")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(diff >= 0 ? .green : .orange)
                }
            }

            HStack(spacing: 12) {
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
            Text(value.formattedCurrency(style: .compact))
                .font(.system(.caption, design: .monospaced, weight: .semibold))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 策略省息 Banner
    private var strategySavingBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "bolt.fill")
                .font(.title2)
                .foregroundStyle(.yellow)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(scenario.repaymentStrategy.title) 效果显著")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)

                Text("预计累计节约利息 \(result.strategyInterestSaved.formattedCurrency())，且使无债结清日提前 \(result.strategyMonthsSaved) 个月！")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.9))
            }

            Spacer()
        }
        .padding(12)
        .background(
            LinearGradient(
                colors: [Color.orange, Color.red.opacity(0.85)],
                startPoint: .leading,
                endPoint: .trailing
            ),
            in: RoundedRectangle(cornerRadius: 12)
        )
    }

    // MARK: - 交互沙盘调节控制台
    private var sandboxControlsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button {
                withAnimation(.spring(duration: 0.28)) {
                    isControlsExpanded.toggle()
                }
            } label: {
                HStack {
                    Label("情景沙盘推演调节器", systemImage: "slider.horizontal.3")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Spacer()

                    Image(systemName: isControlsExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if isControlsExpanded {
                VStack(spacing: 14) {
                    // 1. 收入波动滑块
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("月度收入波动冲击")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(incomeShockLabel(scenario.incomeAdjustmentPct))
                                .font(.caption.weight(.bold))
                                .foregroundStyle(scenario.incomeAdjustmentPct < 0 ? .red : (scenario.incomeAdjustmentPct > 0 ? .green : .primary))
                        }

                        Slider(
                            value: $scenario.incomeAdjustmentPct,
                            in: -0.50...0.50,
                            step: 0.05
                        )
                        .tint(scenario.incomeAdjustmentPct < 0 ? .red : .blue)
                        .sensoryFeedback(.impact(weight: .light), trigger: scenario.incomeAdjustmentPct)
                    }

                    // 2. 突发单笔支出模拟
                    VStack(alignment: .leading, spacing: 6) {
                        Text("突发单笔大额支出")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 8) {
                            lumpSumButton(amount: 0, label: "无")
                            lumpSumButton(amount: 10000, label: "¥1万")
                            lumpSumButton(amount: 30000, label: "¥3万")
                            lumpSumButton(amount: 50000, label: "¥5万")
                        }
                    }

                    // 3. 负债加速清偿策略选择
                    VStack(alignment: .leading, spacing: 6) {
                        Text("负债加速还款策略")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Picker("还款策略", selection: $scenario.repaymentStrategy) {
                            ForEach(RepaymentStrategy.allCases) { strat in
                                Text(strat.shortTitle).tag(strat)
                            }
                        }
                        .pickerStyle(.segmented)
                        .sensoryFeedback(.selection, trigger: scenario.repaymentStrategy)

                        Text(scenario.repaymentStrategy.description)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.top, 2)
                    }

                    Divider()

                    // 控制按钮
                    HStack(spacing: 12) {
                        if scenario.isModifiedFromBaseline {
                            Button {
                                withAnimation {
                                    scenario.reset()
                                }
                            } label: {
                                Label("重置为基准", systemImage: "arrow.counterclockwise")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        if scenario.isModifiedFromBaseline {
                            Button(action: onCommitAsBaseline) {
                                Text("固化为新基准")
                                    .font(.subheadline.weight(.semibold))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 6)
                                    .background(Color.accentColor, in: Capsule())
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private func lumpSumButton(amount: Double, label: String) -> some View {
        let isSelected = abs(scenario.lumpSumExpense - amount) < 0.01
        return Button {
            withAnimation {
                scenario.lumpSumExpense = amount
            }
        } label: {
            Text(label)
                .font(.caption.weight(isSelected ? .bold : .regular))
                .foregroundStyle(isSelected ? .white : .primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
        }
        .sensoryFeedback(.impact(weight: .light), trigger: scenario.lumpSumExpense)
    }

    private func incomeShockLabel(_ pct: Double) -> String {
        if abs(pct) < 0.001 {
            return "正常基准 (0%)"
        } else if pct > 0 {
            return "收入增长 (+\(Int(pct * 100))%)"
        } else {
            return "承压受损 (\(Int(pct * 100))%)"
        }
    }
}
