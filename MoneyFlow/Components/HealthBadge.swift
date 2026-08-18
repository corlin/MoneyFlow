import SwiftUI

struct HealthBadge: View {
    let annualRate: Double
    let threshold: Double

    var isBelowThreshold: Bool {
        annualRate <= threshold
    }

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(isBelowThreshold ? Color.appHealthyDebt : Color.appWarningDebt)
                .frame(width: 6, height: 6)

            Text(isBelowThreshold ? "低于基准" : "需关注")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(isBelowThreshold ? .appHealthyDebt : .appWarningDebt)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(isBelowThreshold ? Color.appHealthyDebtLight : Color.appWarningDebtLight)
        .clipShape(Capsule())
        .accessibilityLabel(isBelowThreshold ? "利率低于自定基准" : "利率高于自定基准，需要关注")
    }
}
