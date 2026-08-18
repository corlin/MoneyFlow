import SwiftUI

struct CFPInsightsCard: View {
    let analysis: DebtHealthAnalysis
    var onExplorePlanning: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 头部
            HStack {
                Label("CFP 财务体检与智能诊断", systemImage: "sparkles")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                dsrBadgeView(analysis.dsrStatus, ratio: analysis.dsrRatio)
            }

            // 核心三维健康矩阵
            HStack(spacing: 12) {
                metricBox(
                    title: "偿债收入比 (DSR)",
                    value: "\(Int(analysis.dsrRatio * 100))%",
                    subtitle: analysis.dsrStatus.shortTitle,
                    color: dsrColor(analysis.dsrStatus)
                )

                metricBox(
                    title: "应急储备覆盖",
                    value: "\(String(format: "%.1f", analysis.emergencyCoverageMonths)) 个月",
                    subtitle: "目标 \(analysis.emergencyTargetMonths) 个月",
                    color: analysis.isEmergencyFundAdequate ? .blue : .orange
                )

                metricBox(
                    title: "加权负债成本",
                    value: String(format: "%.2f%%", analysis.wacdAnnualRate * 100),
                    subtitle: "WACD 年化",
                    color: analysis.wacdAnnualRate > 0.05 ? .orange : .primary
                )
            }

            // 智能行动建议列表
            if !analysis.insights.isEmpty {
                VStack(spacing: 10) {
                    ForEach(analysis.insights) { insight in
                        insightRow(insight)
                    }
                }
            }

            // 底部快捷通道
            Button(action: onExplorePlanning) {
                HStack {
                    Text("进入「规划沙盘」推演还贷与多目标")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.subheadline)
                }
                .foregroundStyle(Color.accentColor)
                .padding(.top, 4)
            }
        }
        .padding(16)
        .background(Color.appCardBackground, in: RoundedRectangle(cornerRadius: 16))
    }

    private func metricBox(title: String, value: String, subtitle: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(color)
                .monospacedDigit()
                .lineLimit(1)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
    }

    private func insightRow(_ insight: FinancialInsight) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: insight.type.icon)
                .font(.subheadline)
                .foregroundStyle(insightColor(insight.type))
                .frame(width: 20)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(insight.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(insight.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)

                if let hint = insight.actionHint {
                    Text("💡 \(hint)")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(Color.accentColor)
                        .padding(.top, 2)
                }
            }
        }
        .padding(10)
        .background(insightColor(insight.type).opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
    }

    private func dsrBadgeView(_ status: DSRStatus, ratio: Double) -> some View {
        Text("DSR \(Int(ratio * 100))% · \(status.shortTitle)")
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(dsrColor(status).opacity(0.15), in: Capsule())
            .foregroundStyle(dsrColor(status))
    }

    private func dsrColor(_ status: DSRStatus) -> Color {
        switch status {
        case .healthy: return .green
        case .warning: return .orange
        case .danger: return .red
        }
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
