import SwiftUI

struct FinancialResilienceHubView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let analysis: DebtHealthAnalysis
    var onExplorePlanning: () -> Void

    private var dsrColor: Color {
        switch analysis.dsrStatus {
        case .healthy: return .appHealthyDebt
        case .warning: return .orange
        case .danger: return .appWarningDebt
        }
    }

    private var emergencyColor: Color {
        analysis.isEmergencyFundAdequate ? .appHealthyDebt : .orange
    }

    // 获取最具价值的单条黄金洞察
    private var goldenInsight: FinancialInsight? {
        analysis.insights.first { $0.type == .urgent } ??
        analysis.insights.first { $0.type == .warning } ??
        analysis.insights.first { $0.type == .recommendation } ??
        analysis.insights.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 头部标题与状态徽章
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("财务韧性与健康中枢")
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .tracking(-0.2)
                    Text("CFP 偿债承载力与流动性综合体检")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 5) {
                    Circle()
                        .fill(dsrColor)
                        .frame(width: 7, height: 7)
                    Text(analysis.dsrStatus.shortTitle)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(dsrColor)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(dsrColor.opacity(0.12), in: Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(dsrColor.opacity(0.20), lineWidth: 0.5)
                )
            }

            // 核心生命线三率 (Three Core Resilience Numbers) - 呼吸感指标格
            HStack(spacing: 8) {
                metricCell(
                    title: "应急储备",
                    value: "\(String(format: "%.1f", analysis.emergencyCoverageMonths))月",
                    subtext: "目标 \(analysis.emergencyTargetMonths) 个月",
                    color: emergencyColor
                )

                metricCell(
                    title: "偿债比 (DSR)",
                    value: "\(Int(analysis.dsrRatio * 100))%",
                    subtext: analysis.dsrStatus.shortTitle,
                    color: dsrColor
                )

                metricCell(
                    title: "自由月结余",
                    value: analysis.savingsRate > 0 ? "\(Int(analysis.savingsRate * 100))%" : "0%",
                    subtext: "用于目标蓄水",
                    color: analysis.savingsRate > 0.15 ? .appAsset : .secondary
                )
            }

            // 单条高价值黄金行动建议 (Single Golden Actionable Insight)
            if let insight = goldenInsight {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: insight.type.icon)
                        .font(.subheadline)
                        .foregroundStyle(insightColor(insight.type))
                        .frame(width: 20)
                        .padding(.top, 2)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(insight.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)

                        Text(insight.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()
                }
                .padding(12)
                .background(
                    insightColor(insight.type).opacity(0.06),
                    in: RoundedRectangle(cornerRadius: 12)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(insightColor(insight.type).opacity(0.15), lineWidth: 0.5)
                )
            }

            Divider()
                .opacity(0.6)

            // 底部净现金头寸与规划跳转
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("当前净现金头寸")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(analysis.netCashPosition.formattedCurrencyCompact)
                        .font(.subheadline.bold())
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .foregroundStyle(analysis.netCashPosition < 0 ? Color.appWarningDebt : .primary)
                }

                Spacer()

                Button(action: onExplorePlanning) {
                    HStack(spacing: 5) {
                        Text("推演沙盘与目标")
                            .font(.caption.weight(.semibold))
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.caption)
                    }
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.accentColor.opacity(0.12), in: Capsule())
                }
                .buttonStyle(AppSpringButtonStyle(scaleAmount: 0.95, pressedOpacity: 0.8))
            }
        }
        .padding(16)
        .background(Color.appCardBackground, in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(Color(UIColor.separator).opacity(0.15), lineWidth: 0.5)
        )
    }

    private func metricCell(title: String, value: String, subtext: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(value)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .tracking(-0.3)
                .foregroundStyle(color)
                .monospacedDigit()
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(subtext)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color(UIColor.separator).opacity(0.12), lineWidth: 0.5)
        )
    }

    private func insightColor(_ type: InsightType) -> Color {
        switch type {
        case .urgent: return .red
        case .warning: return .orange
        case .recommendation: return .blue
        case .milestone: return .green
        }
    }
}

