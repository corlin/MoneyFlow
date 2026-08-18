import Foundation

enum CurrencyFormatStyle {
    case standard
    case compact
}

extension Double {
    var formattedCurrency: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "¥"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter.string(from: NSNumber(value: self)) ?? "¥\(self)"
    }

    var formattedCurrencyCompact: String {
        let doubleValue = self
        if abs(doubleValue) >= 10000 {
            let wan = doubleValue / 10000.0
            return String(format: "¥%.2f万", wan)
        } else {
            return formattedCurrency
        }
    }

    func formattedCurrency(style: CurrencyFormatStyle = .standard) -> String {
        switch style {
        case .standard:
            return formattedCurrency
        case .compact:
            return formattedCurrencyCompact
        }
    }

    var formattedPercentage: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)%"
    }

    var doubleValue: Double {
        self
    }
}
