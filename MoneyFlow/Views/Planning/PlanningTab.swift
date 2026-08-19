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

    @State private var scenario: PlanningScenario = .baseline
    @State private var showCommittedToast = false

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
}
