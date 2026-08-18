import SwiftUI

struct CreditCardRow: View {
    let card: CreditCard

    var body: some View {
        VStack(spacing: 10) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { identity; Spacer(); balance }
                VStack(alignment: .leading, spacing: 10) { identity; balance }
            }
            ProgressView(value: card.utilizationRate)
                .tint(utilizationColor)
                .accessibilityLabel("额度使用率")
                .accessibilityValue("百分之 \(Int(card.utilizationRate * 100))")
            ViewThatFits(in: .horizontal) {
                HStack { Text("已用 \(Int(card.utilizationRate * 100))%"); Spacer(); Text("总额度 \(card.creditLimit.formattedCurrencyCompact)") }
                VStack(alignment: .leading, spacing: 2) { Text("已用 \(Int(card.utilizationRate * 100))%"); Text("总额度 \(card.creditLimit.formattedCurrencyCompact)") }
            }
            .font(.caption2)
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private var identity: some View {
        HStack(spacing: 12) {
            Image(systemName: card.icon)
                .font(.title3).foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(Color.purple)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(card.name).font(.headline)
                Text("账单日 \(card.billingDay)日 · 还款日 \(card.dueDay)日").font(.caption).foregroundColor(.secondary)
            }
        }
    }

    private var balance: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("当前欠款").font(.caption2).foregroundColor(.secondary)
            CurrencyText(amount: card.currentBalance, font: .system(.body, design: .rounded), weight: .bold, color: card.currentBalance > 0 ? .appLiability : .primary)
        }
    }

    private var utilizationColor: Color {
        card.utilizationRate > 0.8 ? .appLiability : (card.utilizationRate > 0.5 ? .appWarningDebt : .purple)
    }
}
