import SwiftUI

struct FinancialResilienceHubView: View {
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
                VStack(alignment: .leading, spacing: 2) {
                    Text("财务韧性与健康中枢")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("CFP 偿债承载力与流动性综合体检")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 4) {
                    Circle()
                        .fill(dsrColor)
                        .frame(width: 8, height: 8)
                    Text(analysis.dsrStatus.shortTitle)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(dsrColor)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(dsrColor.opacity(0.12), in: Capsule())
            }

            // 核心生命线三率 (Three Core Resilience Numbers)
            HStack(spacing: 10) {
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
                        .frame(width: 18)
                        .padding(.top, 2)

                    VStack(alignment: .leading, spacing: 2) {
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
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
            }

            Divider()

            // 底部净现金头寸与规划跳转
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("当前净现金头寸")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(analysis.netCashPosition.formattedCurrencyCompact)
                        .font(.subheadline.bold())
                        .monospacedDigit()
                        .foregroundStyle(analysis.netCashPosition < 0 ? Color.appWarningDebt : .primary)
                }

                Spacer()

                Button(action: onExplorePlanning) {
                    HStack(spacing: 4) {
                        Text("推演沙盘与目标")
                            .font(.caption.weight(.semibold))
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.caption)
                    }
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.accentColor.opacity(0.10), in: Capsule())
                }
            }
        }
        .padding(16)
        .background(Color.appCardBackground, in: RoundedRectangle(cornerRadius: 16))
    }

    private func metricCell(title: String, value: String, subtext: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(value)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(color)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(subtext)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
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
