import SwiftUI

extension Color {
    // 主题色系
    static let appPrimary = Color(red: 0.08, green: 0.45, blue: 0.85) // 稳健蓝
    static let appBackground = Color(UIColor.systemGroupedBackground)
    static let appCardBackground = Color(UIColor.secondarySystemGroupedBackground)

    // 资产/收益（绿色）
    static let appAsset = Color(red: 0.18, green: 0.70, blue: 0.38)
    static let appAssetLight = Color(red: 0.18, green: 0.70, blue: 0.38).opacity(0.15)

    // 负债/支出（红色）
    static let appLiability = Color(red: 0.90, green: 0.28, blue: 0.28)
    static let appLiabilityLight = Color(red: 0.90, green: 0.28, blue: 0.28).opacity(0.15)

    // 低于利率基准
    static let appHealthyDebt = Color(red: 0.12, green: 0.58, blue: 0.75)
    static let appHealthyDebtLight = Color(red: 0.12, green: 0.58, blue: 0.75).opacity(0.15)

    // 高于利率基准
    static let appWarningDebt = Color(red: 0.95, green: 0.45, blue: 0.15)
    static let appWarningDebtLight = Color(red: 0.95, green: 0.45, blue: 0.15).opacity(0.15)

    // 边框和细线
    static let appBorder = Color(UIColor.separator)
}
