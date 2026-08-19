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
                    Text("🌟 我的心愿与储蓄目标")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text("每月结余资金将按优先级自动分配至各心愿")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    showingAddSheet = true
                } label: {
                    Label("添加心愿", systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.semibold))
                }
            }

            // 超额预备警告
            if summary.isOverAllocated {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("已预备存款总额 (\(summary.totalEarmarkedAmount.formattedCurrencyCompact)) 超过了当前可用总现金 (\(totalCash.formattedCurrencyCompact))，建议适当调低各目标的预备金额。")
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
