import SwiftUI

struct GoalCardView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let item: GoalProjectionItem
    var onEdit: () -> Void
    var onDelete: () -> Void

    private var goal: FinancialGoal { item.goal }

    var body: some View {
        Button(action: onEdit) {
            VStack(alignment: .leading, spacing: 14) {
                // 头部：图标、名称与优先级
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: goal.category.systemImage)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(goal.category.themeColor)
                        .frame(width: 36, height: 36)
                        .background(goal.category.themeColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(goal.category.themeColor.opacity(0.20), lineWidth: 0.5)
                        )

                    VStack(alignment: .leading, spacing: 3) {
                        Text(goal.name)
                            .font(.headline)
                            .foregroundStyle(.primary)

                        HStack(spacing: 6) {
                            Text(goal.category.title)
                                .font(.caption2)
                                .foregroundStyle(.secondary)

                            Text("•")
                                .font(.system(size: 8))
                                .foregroundStyle(.tertiary)

                            Text(goal.priority.shortTitle)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(priorityColor(goal.priority))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
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
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(width: 28, height: 28)
                            .background(Color(.tertiarySystemGroupedBackground), in: Circle())
                    }
                    .buttonStyle(.plain)
                }

                // 核心金额指标
                HStack(alignment: .lastTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("当前已攒金额")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(item.projectedTotal.formattedCurrency)
                            .font(.system(.title3, design: .rounded, weight: .bold))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                            .foregroundStyle(.primary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("心愿总额")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(item.targetAmount.formattedCurrency)
                            .font(.system(.subheadline, design: .monospaced, weight: .medium))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }

                // 流体三段式资金胶囊进度条
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
                        Text("已备存款: \(item.initialEarmarked.formattedCurrencyCompact)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    if item.projectedIrrigation > 0 {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(goal.category.themeColor.opacity(0.45))
                                .frame(width: 6, height: 6)
                            Text("每月自动攒入: +\(item.projectedIrrigation.formattedCurrencyCompact)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    Text("\(Int(item.progressRatio * 100))%")
                        .font(.caption.weight(.bold))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .foregroundStyle(item.progressRatio >= 1.0 ? .green : .primary)
                }

                Divider()
                    .opacity(0.6)

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
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color(UIColor.separator).opacity(0.12), lineWidth: 0.5)
            )
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.appCard)
        .accessibilityHint("打开并编辑心愿目标")
    }

    @ViewBuilder
    private var etaStatusView: some View {
        if item.projectedTotal >= item.targetAmount {
            if let date = item.completionDate {
                HStack(spacing: 4) {
                    Image(systemName: "flag.checkered")
                        .font(.system(size: 10))
                    Text("🎉 预计 \(date.yearMonthString) 实现")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(.green)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.green.opacity(0.12), in: Capsule())
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                    Text("🎉 目标已达成！")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(.green)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.green.opacity(0.12), in: Capsule())
            }
        } else if !item.isOnTrack && item.delayedMonths > 0 {
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 10))
                Text("⚠️ 预计推迟 \(item.delayedMonths) 个月")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(.orange)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.orange.opacity(0.12), in: Capsule())
        } else {
            HStack(spacing: 4) {
                Image(systemName: "hourglass")
                    .font(.system(size: 10))
                Text("⏳ 尚差 \(item.remainingGap.formattedCurrencyCompact)")
                    .font(.system(size: 11, weight: .medium))
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

/// 流体三段式胶囊进度条组件
struct MultiSegmentProgressBar: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
                Capsule()
                    .fill(Color(.tertiarySystemFill))
                    .frame(height: 6)

                HStack(spacing: 0) {
                    // 存量分账段
                    if earmarkedWidth > 0 {
                        Capsule()
                            .fill(color)
                            .frame(width: max(3, earmarkedWidth), height: 6)
                    }

                    // 动态灌溉段
                    if irrigationWidth > 0 {
                        Capsule()
                            .fill(color.opacity(0.45))
                            .frame(width: max(3, irrigationWidth), height: 6)
                    }
                }
            }
        }
        .frame(height: 6)
        .animation(AppMotion.animation(for: .momentum, reduceMotion: reduceMotion), value: earmarkedRatio + irrigationRatio)
    }
}

