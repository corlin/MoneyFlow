import SwiftUI

struct LiquidityBufferCard: View {
    let summary: LiquidityBufferSummary

    private var needsAttention: Bool { summary.firstShortfall != nil }
    private var accent: Color { needsAttention ? .appWarningDebt : .appPrimary }
    private var heroTitle: String {
        summary.coveredMonths == 0 && needsAttention ? "当前预计缺口" : "预计可支撑"
    }
    private var heroValue: String {
        if summary.coveredMonths == 0, let shortfall = summary.firstShortfall {
            return abs(shortfall.endingCash).formattedCurrencyCompact
        }
        if summary.firstShortfall == nil, summary.horizonMonths > 0 {
            return "\(summary.horizonMonths)+ 个月"
        }
        return "\(summary.coveredMonths) 个月"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "shield.lefthalf.filled")
                    .foregroundStyle(accent)
                    .accessibilityHidden(true)
                Text("偿债缓冲").font(.headline)
                Spacer()
                Text(needsAttention ? "需关注" : "当前稳定")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(accent)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(heroTitle).font(.caption).foregroundStyle(.secondary)
                Text(heroValue)
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .minimumScaleFactor(0.75)
                    .monospacedDigit()
                    .foregroundStyle(accent)
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 24) { detailMetrics }
                VStack(alignment: .leading, spacing: 10) { detailMetrics }
            }

            if !summary.hasMonthlyIncomeAssumption {
                Label("尚未设置每月预计收入，结果会偏保守", systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .background(Color.appCardBackground, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("liquidity-buffer-card")
        .accessibilityLabel(accessibilityText)
    }

    @ViewBuilder
    private var detailMetrics: some View {
        metric(title: "最低预计余额", value: summary.minimumBalance.formattedCurrencyCompact)
        if let shortfall = summary.firstShortfall {
            metric(title: "首次缺口", value: "\(shortfall.date.yearMonthString) · \(abs(shortfall.endingCash).formattedCurrencyCompact)")
        } else {
            metric(title: "预测区间", value: "未来 \(summary.horizonMonths) 个月")
        }
    }

    private func metric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.subheadline.weight(.semibold)).monospacedDigit()
        }
    }

    private var accessibilityText: String {
        var parts = ["偿债缓冲", heroTitle, heroValue, "最低预计余额 \(summary.minimumBalance.formattedCurrency)"]
        if let shortfall = summary.firstShortfall {
            parts.append("首次缺口 \(shortfall.date.yearMonthString)，\(abs(shortfall.endingCash).formattedCurrency)")
        }
        if !summary.hasMonthlyIncomeAssumption { parts.append("尚未设置每月预计收入，结果会偏保守") }
        return parts.joined(separator: "。")
    }
}
