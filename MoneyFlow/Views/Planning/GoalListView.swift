import SwiftUI
import SwiftData

struct GoalListView: View {
    @Environment(\.modelContext) private var modelContext
    let summary: MultiGoalSummary
    let totalCash: Double
    let activeLoans: [Loan]
    var estimatedMonthlyMustPay: Double = 5000

    @State private var showingAddSheet = false
    @State private var editingGoal: FinancialGoal? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 模块头部
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("多目标蓄水矩阵")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text("月度自由现金流将按优先级自动注入各目标")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    showingAddSheet = true
                } label: {
                    Label("新建目标", systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.semibold))
                }
            }

            // 超额分账警告
            if summary.isOverAllocated {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("存量分账总额 (\(summary.totalEarmarkedAmount.formattedCurrencyCompact)) 超过实际总现金 (\(totalCash.formattedCurrencyCompact))，请调整分账金额以防资金假象。")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                .padding(10)
                .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
            }

            if summary.goalProjections.isEmpty {
                emptyStateView
            } else {
                VStack(spacing: 12) {
                    ForEach(summary.goalProjections) { item in
                        GoalCardView(
                            item: item,
                            onEdit: { editingGoal = item.goal },
                            onDelete: { deleteGoal(item.goal) }
                        )
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            GoalFormSheet(
                goalToEdit: nil,
                totalCash: totalCash,
                totalExistingEarmarked: summary.totalEarmarkedAmount,
                activeLoans: activeLoans,
                estimatedMonthlyMustPay: estimatedMonthlyMustPay
            )
        }
        .sheet(item: $editingGoal) { goal in
            GoalFormSheet(
                goalToEdit: goal,
                totalCash: totalCash,
                totalExistingEarmarked: summary.totalEarmarkedAmount,
                activeLoans: activeLoans,
                estimatedMonthlyMustPay: estimatedMonthlyMustPay
            )
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "target")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
                .padding(.top, 8)

            Text("尚未设定规划目标")
                .font(.headline)

            Text("引入 CFP 目标导向规划：设定「应急防线」、「提前还贷」或「置业购车」心愿，系统将自动利用月度结余推演达成时间。")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

            Button {
                showingAddSheet = true
            } label: {
                Text("设定第一个规划目标")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.accentColor, in: Capsule())
                    .foregroundStyle(.white)
            }
            .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private func deleteGoal(_ goal: FinancialGoal) {
        modelContext.delete(goal)
        try? modelContext.save()
    }
}
