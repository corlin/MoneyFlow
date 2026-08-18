import Foundation
import SwiftData

@Model
final class UserSettings {
    var id: UUID = UUID()
    // 用户自定的利率关注基准（例如 0.05 代表 5.0%）
    var rateThreshold: Double = 0.05

    // 现金流预警比例（当月应还债务 / 现金资产 > 该比例触发预警，默认 0.7 即 70%）
    var cashFlowWarningRatio: Double = 0.70

    // 临近还款日提前提醒天数（默认 5 天）
    var reminderDaysBefore: Int = 5

    // 预计每月现金净流入（用于现金流时间线预测，如工资等，默认 0）
    var monthlyEstimatedIncome: Double = 0

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        id: UUID = UUID(),
        rateThreshold: Double = 0.05,
        cashFlowWarningRatio: Double = 0.70,
        reminderDaysBefore: Int = 5,
        monthlyEstimatedIncome: Double = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.rateThreshold = rateThreshold
        self.cashFlowWarningRatio = cashFlowWarningRatio
        self.reminderDaysBefore = reminderDaysBefore
        self.monthlyEstimatedIncome = monthlyEstimatedIncome
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
