import SwiftUI

struct LoanRow: View {
    let loan: Loan
    let rateThreshold: Double

    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: loan.icon)
                    .font(.title3).foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    ViewThatFits(in: .horizontal) {
                        HStack { Text(loan.name).font(.headline); Spacer(); badge }
                        VStack(alignment: .leading, spacing: 6) { Text(loan.name).font(.headline); badge }
                    }
                    Text(loan.repaymentMethod.rawValue + " · 年化 " + loan.latestAnnualRate.formattedRatePercentage)
                    Text("每月\(loan.paymentDayOfMonth)日还款")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            ProgressView(value: loan.progress)
                .tint(accentColor)
                .accessibilityLabel("还款进度")
                .accessibilityValue("已还 \(loan.paidPeriods) 期，共 \(loan.totalPeriods) 期")

            ViewThatFits(in: .horizontal) {
                HStack { amountBlocks }
                VStack(alignment: .leading, spacing: 10) { amountBlocks }
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }

    private var accentColor: Color { loan.annualRate <= rateThreshold ? .appHealthyDebt : .appWarningDebt }
    private var badge: some View { HealthBadge(annualRate: loan.annualRate, threshold: rateThreshold) }

    @ViewBuilder private var amountBlocks: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("剩余本金").font(.caption2).foregroundColor(.secondary)
            CurrencyText(amount: loan.remainingPrincipal, font: .system(.body, design: .rounded), weight: .bold)
        }
        Spacer()
        VStack(alignment: .leading, spacing: 2) {
            Text("当前月供").font(.caption2).foregroundColor(.secondary)
            CurrencyText(amount: loan.monthlyPayment, font: .system(.body, design: .rounded), weight: .semibold, color: .appLiability)
        }
    }
}
