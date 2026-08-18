import SwiftUI

struct CashAccountRow: View {
    let account: CashAccount

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 14) { identity; Spacer(); balance }
            VStack(alignment: .leading, spacing: 10) { identity; balance }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private var identity: some View {
        HStack(spacing: 14) {
            Image(systemName: account.icon)
                .font(.title3).foregroundColor(.white)
                .frame(width: 42, height: 42)
                .background(Color.appAsset)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(account.name).font(.body.weight(.medium))
                if !account.note.isEmpty {
                    Text(account.note).font(.caption).foregroundColor(.secondary).lineLimit(2)
                }
            }
        }
    }

    private var balance: some View {
        CurrencyText(amount: account.balance, font: .system(.body, design: .rounded), weight: .semibold)
    }
}
