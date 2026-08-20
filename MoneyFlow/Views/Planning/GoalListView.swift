import SwiftUI
import SwiftData

struct GoalListView: View {
    @Environment(\.modelContext) private var modelContext
    let summary: MultiGoalSummary
    let totalCash: Double
    let activeLoans: [Loan]
    var estimatedMonthlyMustPay: Double = 5000

    @State private var showingQuickAddSheet = false
    @State private var showingFullAddSheet = false
    @State private var editingGoal: FinancialGoal? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 模块头部
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("🌟 我的生活心愿罐")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text("每月自由余钱自动累积，还可随时向罐中存钱")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    showingQuickAddSheet = true
                } label: {
                    Label("新建心愿", systemImage: "plus.circle.fill")
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
                        WishlistJarCardView(
                            goal: item.goal,
                            monthlySurplus: item.projectedIrrigation > 0 ? (item.projectedIrrigation / 12.0) : 500,
                            onEdit: { editingGoal = item.goal }
                        )
                    }
                }
            }
        }
        .sheet(isPresented: $showingQuickAddSheet) {
            WishlistQuickAddSheet {
                showingFullAddSheet = true
            }
        }
        .sheet(isPresented: $showingFullAddSheet) {
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
            Image(systemName: "wand.and.sparkles")
                .font(.system(size: 36))
                .foregroundStyle(Color.appPrimary)
                .padding(.top, 8)

            Text("设立您的第一个生活心愿罐")
                .font(.headline)

            Text("无论是换新手机、年假旅行，还是为父母预约体检，建立心愿罐后系统将自动推演达成月份，让存钱充满动力！")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

            Button {
                showingQuickAddSheet = true
            } label: {
                Text("选个心愿模版开始 📱✈️")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 9)
                    .background(Color.appPrimary, in: Capsule())
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
