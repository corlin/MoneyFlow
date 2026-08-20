import SwiftUI
import SwiftData

struct WishlistJarCardView: View {
    @Environment(\.modelContext) private var modelContext
    let goal: FinancialGoal
    let monthlySurplus: Double
    var onEdit: () -> Void

    @State private var showingDepositSuccess = false

    private var progressRatio: Double {
        guard goal.targetAmount > 0 else { return 0 }
        return min(1.0, max(0, goal.currentEarmarkedAmount / goal.targetAmount))
    }

    private var isCompleted: Bool {
        goal.currentEarmarkedAmount >= goal.targetAmount && goal.targetAmount > 0
    }

    private var remainingAmount: Double {
        max(0, goal.targetAmount - goal.currentEarmarkedAmount)
    }

    // 智能推算预计达成时间 (Smart ETA)
    private var smartEtaText: String {
        if isCompleted {
            return "🎉 已达成心愿！"
        }
        guard monthlySurplus > 50 else {
            return "💡 增加每月结余可加速实现"
        }

        let monthsNeeded = Int(ceil(remainingAmount / monthlySurplus))
        let calendar = Calendar.current
        if let targetDate = calendar.date(byAdding: .month, value: monthsNeeded, to: Date()) {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy年M月"
            return "按当前余钱，预计 \(formatter.string(from: targetDate)) 达成 🎉"
        }
        return "预计约 \(monthsNeeded) 个月后达成"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 头部：图标 + 标题 + 优先级胶囊
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(goal.category.themeColor.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: goal.category.systemImage)
                        .font(.headline)
                        .foregroundStyle(goal.category.themeColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(goal.name)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(goal.category.title)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(action: onEdit) {
                    Image(systemName: "pencil.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }

            // 存钱罐进度条
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text("已攒 ¥\(Int(goal.currentEarmarkedAmount))")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(goal.category.themeColor)
                        .monospacedDigit()

                    Text("/ 目标 ¥\(Int(goal.targetAmount))")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text("\(Int(progressRatio * 100))%")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(goal.category.themeColor)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color(.tertiarySystemFill))
                            .frame(height: 8)

                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [goal.category.themeColor.opacity(0.7), goal.category.themeColor],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * CGFloat(progressRatio), height: 8)
                    }
                }
                .frame(height: 8)
            }

            // 大白话预测横幅
            HStack(spacing: 6) {
                Image(systemName: isCompleted ? "checkmark.seal.fill" : "clock.badge.checkmark")
                    .font(.caption)
                    .foregroundStyle(isCompleted ? .green : .secondary)

                Text(smartEtaText)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .padding(.vertical, 2)

            Divider()
                .opacity(0.5)

            // 快捷存入投币按钮
            HStack {
                Text(remainingAmount > 0 ? "还需 ¥\(Int(remainingAmount))" : "目标已达成")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer()

                if !isCompleted {
                    HStack(spacing: 8) {
                        quickDepositButton(amount: 200)
                        quickDepositButton(amount: 500)
                    }
                } else {
                    Text("可去实现愿望啦 ✨")
                        .font(.caption.bold())
                        .foregroundStyle(.green)
                }
            }
        }
        .padding(16)
        .background(Color.appCardBackground, in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(Color(UIColor.separator).opacity(0.12), lineWidth: 0.5)
        )
        .sensoryFeedback(.success, trigger: showingDepositSuccess)
    }

    private func quickDepositButton(amount: Double) -> some View {
        Button {
            deposit(amount: amount)
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "plus")
                    .font(.system(size: 9, weight: .bold))
                Text("¥\(Int(amount))")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(goal.category.themeColor.opacity(0.12))
            .foregroundStyle(goal.category.themeColor)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func deposit(amount: Double) {
        let depositActual = min(amount, remainingAmount)
        goal.currentEarmarkedAmount += depositActual
        goal.updatedAt = Date()
        try? modelContext.save()
        showingDepositSuccess.toggle()
    }
}
