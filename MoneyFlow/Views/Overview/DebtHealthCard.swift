import SwiftUI

struct DebtHealthCard: View {
    let analysis: DebtHealthAnalysis
    let rateThreshold: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ViewThatFits(in: .horizontal) {
                HStack { heading; Spacer(); badge }
                VStack(alignment: .leading, spacing: 8) { heading; badge }
            }

            HStack(spacing: 3) {
                RoundedRectangle(cornerRadius: 4).fill(Color.appHealthyDebt)
                    .frame(height: 8).frame(maxWidth: .infinity)
                    .layoutPriority(max(analysis.healthyDebtRatio, 0.01))
                RoundedRectangle(cornerRadius: 4).fill(Color.appWarningDebt)
                    .frame(height: 8).frame(maxWidth: .infinity)
                    .layoutPriority(max(analysis.warningDebtRatio, 0.01))
            }
            .accessibilityHidden(true)

            ViewThatFits(in: .horizontal) {
                HStack { structure }
                VStack(alignment: .leading, spacing: 12) { structure }
            }
        }
        .padding()
        .background(Color.appCardBackground, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("负债利率结构").font(.headline)
            Text("按自定基准（≤ " + String(format: "%.1f%%", rateThreshold * 100) + "）划分")
                .font(.caption).foregroundColor(.secondary)
        }
    }

    private var badge: some View {
        Text(analysis.warningDebtRatio == 0 ? "均低于基准" : (analysis.warningDebtRatio < 0.3 ? "低息为主" : "需关注"))
            .font(.caption.bold())
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(analysis.warningDebtRatio < 0.3 ? Color.appHealthyDebtLight : Color.appWarningDebtLight)
            .foregroundColor(analysis.warningDebtRatio < 0.3 ? .appHealthyDebt : .appWarningDebt)
            .clipShape(Capsule())
    }

    @ViewBuilder private var structure: some View {
        metric(title: "低于基准利率", amount: analysis.healthyDebtAmount, ratio: analysis.healthyDebtRatio, color: .appHealthyDebt)
        Spacer()
        metric(title: "高于基准利率", amount: analysis.warningDebtAmount, ratio: analysis.warningDebtRatio, color: .appWarningDebt)
    }

    private func metric(title: String, amount: Double, ratio: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 8, height: 8).accessibilityHidden(true)
                Text(title).font(.caption2).foregroundColor(.secondary)
            }
            CurrencyText(amount: amount, font: .subheadline, weight: .bold)
            Text("占比 \(Int(ratio * 100))%").font(.caption2).foregroundColor(.secondary)
        }
    }
}
