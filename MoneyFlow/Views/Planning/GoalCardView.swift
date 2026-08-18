import SwiftUI

struct GoalCardView: View {
    let item: GoalProjectionItem
    var onEdit: () -> Void
    var onDelete: () -> Void

    private var goal: FinancialGoal { item.goal }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 头部：图标、名称与优先级
            HStack(alignment: .top) {
                Image(systemName: goal.category.systemImage)
                    .font(.title3)
                    .foregroundStyle(goal.category.themeColor)
                    .frame(width: 32, height: 32)
                    .background(goal.category.themeColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 3) {
                    Text(goal.name)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    HStack(spacing: 6) {
                        Text(goal.category.title)
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        Text("•")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)

                        Text(goal.priority.shortTitle)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(priorityColor(goal.priority))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(priorityColor(goal.priority).opacity(0.12), in: Capsule())
                    }
                }

                Spacer()

                Menu {
                    Button(action: onEdit) {
                        Label("编辑目标", systemImage: "pencil")
                    }
                    Button(role: .destructive, action: onDelete) {
                        Label("删除目标", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .padding(6)
                        .contentShape(Rectangle())
                }
            }

            // 核心金额指标
            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("当前累计储备")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(item.projectedTotal.formattedCurrency())
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(.primary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("目标金额")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(item.targetAmount.formattedCurrency())
                        .font(.system(.subheadline, design: .monospaced, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }

            // 三段式资金进度条
            MultiSegmentProgressBar(
                earmarkedRatio: item.earmarkedProgressRatio,
                irrigationRatio: item.irrigationProgressRatio,
                color: goal.category.themeColor
            )

            // 进度图例说明
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(goal.category.themeColor)
                        .frame(width: 6, height: 6)
                    Text("存量分账: \(item.initialEarmarked.formattedCurrency(style: .compact))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if item.projectedIrrigation > 0 {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(goal.category.themeColor.opacity(0.45))
                            .frame(width: 6, height: 6)
                        Text("动态灌溉: +\(item.projectedIrrigation.formattedCurrency(style: .compact))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Text("\(Int(item.progressRatio * 100))%")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(item.progressRatio >= 1.0 ? .green : .primary)
            }

            Divider()

            // 底部：预计达成期 ETA 与 状态标签
            HStack {
                etaStatusView

                Spacer()

                if let date = goal.targetDate {
                    Text("期望: \(date.yearMonthString)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private var etaStatusView: some View {
        if item.projectedTotal >= item.targetAmount {
            if let date = item.completionDate {
                HStack(spacing: 4) {
                    Image(systemName: "flag.checkered")
                        .font(.caption2)
                    Text("预计 \(date.yearMonthString) 达成")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(.green)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.green.opacity(0.12), in: Capsule())
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                    Text("已足额达成")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(.green)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.green.opacity(0.12), in: Capsule())
            }
        } else if !item.isOnTrack && item.delayedMonths > 0 {
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption2)
                Text("预计延期 \(item.delayedMonths) 个月")
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(.orange)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.orange.opacity(0.12), in: Capsule())
        } else {
            HStack(spacing: 4) {
                Image(systemName: "hourglass")
                    .font(.caption2)
                Text("尚余缺口 \(item.remainingGap.formattedCurrency(style: .compact))")
                    .font(.caption.weight(.medium))
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color(.tertiarySystemGroupedBackground), in: Capsule())
        }
    }

    private func priorityColor(_ priority: GoalPriority) -> Color {
        switch priority {
        case .essential: return .red
        case .important: return .orange
        case .aspirational: return .blue
        }
    }
}

/// 三段式进度条组件
struct MultiSegmentProgressBar: View {
    let earmarkedRatio: Double
    let irrigationRatio: Double
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let totalWidth = geo.size.width
            let earmarkedWidth = min(totalWidth, totalWidth * CGFloat(earmarkedRatio))
            let irrigationWidth = min(totalWidth - earmarkedWidth, totalWidth * CGFloat(irrigationRatio))

            ZStack(alignment: .leading) {
                // 背景槽
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.tertiarySystemFill))
                    .frame(height: 8)

                HStack(spacing: 0) {
                    // 存量分账段
                    if earmarkedWidth > 0 {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(color)
                            .frame(width: earmarkedWidth, height: 8)
                    }

                    // 动态灌溉段
                    if irrigationWidth > 0 {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(color.opacity(0.45))
                            .frame(width: irrigationWidth, height: 8)
                    }
                }
            }
        }
        .frame(height: 8)
    }
}
