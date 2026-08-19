import Foundation

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
        if abs(self) >= 10000 {
            let wan = self / 10000.0
            return String(format: "¥%.2f万", wan)
        } else {
            return formattedCurrency
        }
    }

    var formattedPercentage: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 4
        formatter.minimumFractionDigits = 2
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)%"
    }

    /// 年化利率百分比格式化：精确到小数点后 4 位 (如 3.1250%, 3.8500%)
    var formattedRatePercentage: String {
        let percentValue = self * 100.0
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 4
        let formattedNumber = formatter.string(from: NSNumber(value: percentValue)) ?? String(format: "%.4f", percentValue)
        return "\(formattedNumber)%"
    }
}
