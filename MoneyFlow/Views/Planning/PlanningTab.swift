import SwiftUI
import SwiftData

struct PlanningTab: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Query private var cashAccounts: [CashAccount]
    @Query private var loans: [Loan]
    @Query private var creditCards: [CreditCard]
    @Query private var goals: [FinancialGoal]
    @Query private var userSettingsList: [UserSettings]
    @Query private var reconciliations: [PaymentReconciliationRecord]
    @Query private var customEvents: [CustomCashFlowEvent]

    @State private var scenario: PlanningScenario = .baseline
    @State private var showCommittedToast = false
    @State private var showOpportunityCostCalculator = false

    private var settings: UserSettings {
        userSettingsList.first ?? UserSettings()
    }

    private var totalCash: Double {
        cashAccounts.reduce(0.0) { $0 + $1.balance }
    }

    private var projectionResult: CashFlowProjectionResult {
        CashFlowProjector.projectAdvancedCashFlow(
            initialCash: totalCash,
            loans: loans,
            creditCards: creditCards,
            goals: goals,
            monthlyIncome: settings.monthlyEstimatedIncome,
            monthlyLivingExpense: settings.monthlyLivingExpense,
            warningRatio: settings.cashFlowWarningRatio,
            monthsCount: 12,
            assumptions: .default,
            scenario: scenario
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    // 顶部流动性与分账快速概览条
                    planningSummaryHeader(result: projectionResult)

                    // 周期性现金流全景日历与智能对账
                    CashFlowCalendarCardView(
                        accounts: cashAccounts,
                        loans: loans,
                        creditCards: creditCards,
                        settings: settings,
                        reconciliations: reconciliations,
                        customEvents: customEvents
                    )

                    // 机会成本精算快捷入口卡片
                    opportunityCostBanner

                    // 动态推演沙盘
                    DynamicCashFlowSandboxView(
                        result: projectionResult,
                        scenario: $scenario,
                        onCommitAsBaseline: commitScenarioToBaseline
                    )

                    // 多目标管理矩阵
                    GoalListView(
                        summary: projectionResult.goalSummary,
                        totalCash: totalCash,
                        activeLoans: loans.filter { $0.remainingPrincipal > 0 },
                        estimatedMonthlyMustPay: projectionResult.currentMonthlyMustPay
                    )
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .background(Color(.systemGroupedBackground))
            .sheet(isPresented: $showOpportunityCostCalculator) {
                OpportunityCostCalculatorView()
            }
            .navigationTitle("规划与沙盘")
            .overlay(alignment: .bottom) {
                if showCommittedToast {
                    Text("已成功固化为新基准")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.8), in: Capsule())
                        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 20)
                }
            }
        }
    }

    private func planningSummaryHeader(result: CashFlowProjectionResult) -> some View {
        let (freeCash, totalEarmarked, _) = MultiGoalEngine.calculateFreeCash(totalCash: totalCash, goals: goals)
        let firstMonthSurplus = result.baselineItems.first?.monthlySurplus ?? 0

        return HStack(spacing: 10) {
            summaryMetricItem(
                title: "自由流动现金",
                value: freeCash.formattedCurrencyCompact,
                subtext: "未锁定",
                color: .blue
            )

            summaryMetricItem(
                title: "已分账目标池",
                value: totalEarmarked.formattedCurrencyCompact,
                subtext: "共 \(goals.count) 个目标",
                color: .purple
            )

            summaryMetricItem(
                title: "月度自由结余",
                value: firstMonthSurplus.formattedCurrencyCompact,
                subtext: "用于动态灌溉",
                color: firstMonthSurplus > 0 ? .green : .red
            )

            summaryMetricItem(
                title: "预测最低现金",
                value: result.troughBalance.formattedCurrencyCompact,
                subtext: result.troughMonthLabel,
                color: result.troughBalance >= 0 ? .primary : .red
            )
        }
    }

    private func summaryMetricItem(title: String, value: String, subtext: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(subtext)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private func commitScenarioToBaseline() {
        // 将沙盘收入调整固化到 UserSettings
        if abs(scenario.incomeAdjustmentPct) > 0.001 {
            let adjustedIncome = max(0.0, settings.monthlyEstimatedIncome * (1.0 + scenario.incomeAdjustmentPct))
            settings.monthlyEstimatedIncome = adjustedIncome
        }

        if abs(scenario.livingExpenseAdjustment) > 0.01 {
            settings.monthlyLivingExpense = max(0.0, settings.monthlyLivingExpense + scenario.livingExpenseAdjustment)
        }

        try? modelContext.save()
        AppMotion.perform(level: .spatial, reduceMotion: reduceMotion) {
            scenario.reset()
            showCommittedToast = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            AppMotion.perform(level: .spatial, reduceMotion: reduceMotion) {
                showCommittedToast = false
            }
        }
    }

    private var opportunityCostBanner: some View {
        Button {
            showOpportunityCostCalculator = true
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [.blue.opacity(0.8), .indigo], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 38, height: 38)
                    Image(systemName: "scalemass.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("还贷 vs 理财机会成本精算")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)

                        Text("NEW")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.blue)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.12), in: Capsule())
                    }

                    Text("大额闲钱提前还贷还是理财？保本临界利率一键测算")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color.blue.opacity(0.15), lineWidth: 0.8)
            )
        }
        .buttonStyle(.appCard)
        .accessibilityHint("打开还贷与理财机会成本精算器")
    }
}
