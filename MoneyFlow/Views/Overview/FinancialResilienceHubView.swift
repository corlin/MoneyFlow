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
                    Text("财务健康与安全看板")
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .tracking(-0.2)
                    Text("手头流动性与每月还款压力评估")
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

            // 核心生命线三率 (Three Core Resilience Numbers) - 直觉生活化指标格
            HStack(spacing: 8) {
                metricCell(
                    title: "安全缓冲",
                    value: "\(String(format: "%.1f", analysis.emergencyCoverageMonths))个月",
                    subtext: analysis.emergencyCoverageMonths >= Double(analysis.emergencyTargetMonths) ? "充裕 · 达标" : "建议备 \(analysis.emergencyTargetMonths) 个月",
                    color: emergencyColor
                )

                metricCell(
                    title: "还贷压力",
                    value: "\(Int(analysis.dsrRatio * 100))%",
                    subtext: analysis.dsrStatus == .healthy ? "占月入\(Int(analysis.dsrRatio*100))% · 轻松" : (analysis.dsrStatus == .warning ? "适中 · 需关注" : "偏高 · 需防范"),
                    color: dsrColor
                )

                metricCell(
                    title: "每月余钱",
                    value: analysis.savingsRate > 0 ? "\(Int(analysis.savingsRate * 100))%" : "0%",
                    subtext: "可用于心愿攒钱",
                    color: analysis.savingsRate > 0.15 ? .appAsset : .secondary
                )
            }

            // 单条高价值黄金行动建议 (Single Golden Actionable Insight)
            if let insight = goldenInsight {
                Button(action: onExplorePlanning) {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: insight.type.icon)
                            .font(.subheadline)
                            .foregroundStyle(insightColor(insight.type))
                            .frame(width: 20)
                            .padding(.top, 2)

                        VStack(alignment: .leading, spacing: 3) {
                            Text("💡 \(insight.title)")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)

                            Text(insight.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.tertiary)
                            .padding(.top, 4)
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
                    .contentShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(AppCardButtonStyle())
                .accessibilityHint("前往推演沙盘与心愿目标")
            }

            Divider()
                .opacity(0.6)

            // 底部可用总资金与规划跳转
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("当前可用总资金")
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
                        Text("查看未来收支与心愿")
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

