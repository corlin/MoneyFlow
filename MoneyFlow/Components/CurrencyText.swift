import SwiftUI

struct CurrencyText: View {
    let amount: Double
    var font: Font = .body
    var weight: Font.Weight = .regular
    var color: Color = .primary
    var isCompact: Bool = false

    var body: some View {
        Text(isCompact ? amount.formattedCurrencyCompact : amount.formattedCurrency)
            .font(font)
            .fontWeight(weight)
            .monospacedDigit()
            .foregroundColor(color)
            .accessibilityLabel(amount.formattedCurrency)
    }
}

#Preview {
    VStack(spacing: 12) {
        CurrencyText(amount: 128500.50, font: .title, weight: .bold, color: .appAsset)
        CurrencyText(amount: 4500000.00, font: .title2, isCompact: true)
        CurrencyText(amount: 3280.00, font: .body, color: .appLiability)
    }
    .padding()
}
