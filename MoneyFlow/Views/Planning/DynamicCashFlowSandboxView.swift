import SwiftUI
import Charts

enum SandboxChartMode: String, CaseIterable, Identifiable {
    case balanceLine = "balanceLine"
    case waterfall = "waterfall"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .balanceLine: return "现金走势"
        case .waterfall: return "收支瀑布"
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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
            // 头部：解耦布局 (Primary Header Bar)
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("动态推演沙盘")
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .tracking(-0.2)

                        if scenario.isModifiedFromBaseline {
                            Text("情景模拟中")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.orange)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.12), in: Capsule())
                                .overlay(
                                    Capsule()
                                        .strokeBorder(Color.orange.opacity(0.25), lineWidth: 0.5)
                                )
                        }
                    }
                    Text("点选下方胶囊即刻观察曲线与目标形变")
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
                .frame(width: 140)
            }

            // 情景重置与固化条 (Contextual Action Bar)
            if scenario.isModifiedFromBaseline {
                HStack(spacing: 12) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.caption)
                        .foregroundStyle(.orange)

                    Text("当前处于情景假设模式")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button("还原基准") {
                        AppMotion.perform(level: .spatial, reduceMotion: reduceMotion) {
                            scenario.reset()
                        }
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                    Button("设为新基准") {
                        onCommitAsBaseline()
                    }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.accentColor)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.orange.opacity(0.18), lineWidth: 0.5)
                )
                .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
            }

            // 核心推演图表区域
            VStack(spacing: 10) {
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
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color(UIColor.separator).opacity(0.12), lineWidth: 0.5)
            )

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
                        colors: [Color.blue.opacity(0.15), Color.blue.opacity(0.01)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                LineMark(
                    x: .value("月份", item.monthLabel),
                    y: .value("基准现金", item.endingCash)
                )
                .foregroundStyle(Color.blue)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))

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
                    .lineStyle(StrokeStyle(lineWidth: 2.2, lineCap: .round, dash: [5, 4]))

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
        .frame(height: 185)
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
        .frame(height: 185)
    }

    // MARK: - 探针明细卡片
    private func monthDetailScrubCard(item: MonthlyCashFlowItem, scenarioItem: MonthlyCashFlowItem?) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text("\(item.monthLabel) 预测明细")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.primary)

                Spacer()

                Text("期末现金: \(item.endingCash.formattedCurrencyCompact)")
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(item.endingCash < 0 ? .red : .blue)

                if let scen = scenarioItem, scenario.isModifiedFromBaseline {
                    let diff = scen.endingCash - item.endingCash
                    Text("(\(diff >= 0 ? "+" : "")\(diff.formattedCurrencyCompact))")
                        .font(.caption2.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(diff >= 0 ? .green : .orange)
                }
            }

            HStack(spacing: 8) {
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
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            Text(value.formattedCurrencyCompact)
                .font(.system(.caption2, design: .monospaced, weight: .semibold))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 沉浸式胶囊手柄控制台 (Pill Handlers)
    private var floatingScenarioPills: some View {
        VStack(alignment: .leading, spacing: 14) {
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
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)

                lumpPill(amount: 0, title: "无")
                lumpPill(amount: 20000, title: "+¥2万")
                lumpPill(amount: 50000, title: "+¥5万")
                Spacer()
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color(UIColor.separator).opacity(0.12), lineWidth: 0.5)
        )
    }

    private func incomePill(pct: Double, title: String) -> some View {
        let isSelected = abs(scenario.incomeAdjustmentPct - pct) < 0.001
        return Button {
            AppMotion.perform(level: .interactive, reduceMotion: reduceMotion) {
                scenario.incomeAdjustmentPct = pct
            }
        } label: {
            Text(title)
                .font(.caption.weight(isSelected ? .bold : .regular))
                .foregroundStyle(isSelected ? .white : .primary)
                .frame(maxWidth: .infinity)
                .frame(height: 32)
                .background(
                    isSelected ? (pct < 0 ? Color.orange : Color.accentColor) : Color(.tertiarySystemGroupedBackground),
                    in: Capsule()
                )
        }
        .buttonStyle(AppSpringButtonStyle(scaleAmount: 0.95, pressedOpacity: 0.85))
        .sensoryFeedback(.impact(weight: .light), trigger: scenario.incomeAdjustmentPct)
    }

    private func strategyPill(_ strat: RepaymentStrategy) -> some View {
        let isSelected = scenario.repaymentStrategy == strat
        return Button {
            AppMotion.perform(level: .interactive, reduceMotion: reduceMotion) {
                scenario.repaymentStrategy = strat
            }
        } label: {
            Text(strat.shortTitle)
                .font(.caption.weight(isSelected ? .bold : .regular))
                .foregroundStyle(isSelected ? .white : .primary)
                .frame(maxWidth: .infinity)
                .frame(height: 32)
                .background(
                    isSelected ? Color.accentColor : Color(.tertiarySystemGroupedBackground),
                    in: Capsule()
                )
        }
        .buttonStyle(AppSpringButtonStyle(scaleAmount: 0.95, pressedOpacity: 0.85))
        .sensoryFeedback(.selection, trigger: scenario.repaymentStrategy)
    }

    private func lumpPill(amount: Double, title: String) -> some View {
        let isSelected = abs(scenario.lumpSumExpense - amount) < 0.01
        return Button {
            AppMotion.perform(level: .interactive, reduceMotion: reduceMotion) {
                scenario.lumpSumExpense = amount
            }
        } label: {
            Text(title)
                .font(.caption2.weight(isSelected ? .bold : .regular))
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 12)
                .frame(height: 28)
                .background(
                    isSelected ? Color.orange : Color(.tertiarySystemGroupedBackground),
                    in: Capsule()
                )
        }
        .buttonStyle(AppSpringButtonStyle(scaleAmount: 0.95, pressedOpacity: 0.85))
        .sensoryFeedback(.impact(weight: .light), trigger: scenario.lumpSumExpense)
    }
}

